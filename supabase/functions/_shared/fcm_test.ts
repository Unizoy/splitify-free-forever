import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  base64url,
  classifyFcmError,
  createFcmClient,
  FCM_SCOPE,
  type FcmMessage,
  GOOGLE_TOKEN_URL,
  importPrivateKey,
  parseServiceAccount,
  type ServiceAccount,
  signJwt,
  TOKEN_CACHE_MS,
} from "./fcm.ts";
import type { FetchFn } from "./http.ts";

// A throwaway RSA key generated per test run: no real key is ever committed.
const pair = await crypto.subtle.generateKey(
  {
    name: "RSASSA-PKCS1-v1_5",
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: "SHA-256",
  },
  true,
  ["sign", "verify"],
);
const der = new Uint8Array(
  await crypto.subtle.exportKey("pkcs8", pair.privateKey),
);
const b64 = btoa(String.fromCharCode(...der)).match(/.{1,64}/g)!.join("\n");
const PEM = `-----BEGIN PRIVATE KEY-----\n${b64}\n-----END PRIVATE KEY-----\n`;

const SA: ServiceAccount = {
  project_id: "splitify-test",
  client_email: "push@splitify-test.iam.gserviceaccount.com",
  private_key: PEM,
  token_uri: GOOGLE_TOKEN_URL,
};

const MESSAGE: FcmMessage = {
  token: "device-1",
  notification: { title: "Dinner", body: "Rahul added ₹1,200" },
  data: { route: "/groups/g1" },
  android: { priority: "HIGH", notification: { channel_id: "expenses" } },
};

function decodePart(part: string): Record<string, unknown> {
  const b64 = part.replace(/-/g, "+").replace(/_/g, "/");
  return JSON.parse(atob(b64 + "=".repeat((4 - b64.length % 4) % 4)));
}

/** Routes token and FCM calls to handlers; counts calls. */
function mockGoogle(fcm: (n: number) => Response, oauthStatus = 200) {
  const calls = {
    oauth: 0,
    fcm: 0,
    bodies: [] as string[],
    auth: [] as string[],
  };
  const fn: FetchFn = (input, init) => {
    const url = String(input);
    if (url === GOOGLE_TOKEN_URL) {
      calls.oauth++;
      calls.bodies.push(String(init?.body));
      return Promise.resolve(Response.json(
        oauthStatus === 200
          ? { access_token: `tok-${calls.oauth}`, expires_in: 3599 }
          : { error: "invalid_grant" },
        { status: oauthStatus },
      ));
    }
    calls.fcm++;
    calls.auth.push(new Headers(init?.headers).get("Authorization") ?? "");
    assertEquals(
      url,
      "https://fcm.googleapis.com/v1/projects/splitify-test/messages:send",
    );
    return Promise.resolve(fcm(calls.fcm));
  };
  return { fn, calls };
}

const fcmError = (status: number, code: string, errorCode?: string) =>
  Response.json({
    error: {
      code: status,
      status: code,
      details: errorCode
        ? [{
          "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
          errorCode,
        }]
        : [],
    },
  }, { status });

Deno.test("parseServiceAccount reads the key file and never echoes it on errors", () => {
  const sa = parseServiceAccount(
    JSON.stringify({ ...SA, token_uri: undefined }),
  );
  assertEquals(sa.token_uri, GOOGLE_TOKEN_URL);
  assertEquals(sa.project_id, "splitify-test");
  assertThrows(() => parseServiceAccount("{"), Error, "not valid JSON");
  const err = assertThrows(
    () => parseServiceAccount(JSON.stringify({ ...SA, client_email: "" })),
    Error,
    "client_email",
  );
  assert(!err.message.includes("PRIVATE KEY"));
});

Deno.test("base64url has no padding or URL-unsafe characters", () => {
  assertEquals(base64url(new Uint8Array([251, 255, 191])), "-_-_");
  assertEquals(base64url("ab"), "YWI");
});

Deno.test("signJwt makes an RS256 assertion that verifies with the public key", async () => {
  const key = await importPrivateKey(PEM);
  const jwt = await signJwt(SA, key, Date.UTC(2026, 10, 21, 1, 0, 0));
  const [h, c, s] = jwt.split(".");
  assertEquals(decodePart(h), { alg: "RS256", typ: "JWT" });
  const iat = Date.UTC(2026, 10, 21, 1, 0, 0) / 1000;
  assertEquals(decodePart(c), {
    iss: SA.client_email,
    scope: FCM_SCOPE,
    aud: GOOGLE_TOKEN_URL,
    iat,
    exp: iat + 3600,
  });
  const sigB64 = s.replace(/-/g, "+").replace(/_/g, "/");
  const sig = Uint8Array.from(
    atob(sigB64 + "=".repeat((4 - sigB64.length % 4) % 4)),
    (ch) => ch.charCodeAt(0),
  );
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    pair.publicKey,
    sig,
    new TextEncoder().encode(`${h}.${c}`),
  );
  assert(ok);
});

Deno.test("the access token is fetched once, cached for 50 min, then refreshed", async () => {
  let now = Date.UTC(2026, 10, 21);
  const g = mockGoogle(() => Response.json({ name: "projects/p/messages/1" }));
  const client = createFcmClient(SA, { fetch: g.fn, now: () => now });
  const [a, b] = await Promise.all([
    client.send(MESSAGE),
    client.send(MESSAGE),
  ]);
  assertEquals(a, { ok: true, name: "projects/p/messages/1" });
  assertEquals(b.ok, true);
  assertEquals(g.calls.oauth, 1);
  const form = new URLSearchParams(g.calls.bodies[0]);
  assertEquals(
    form.get("grant_type"),
    "urn:ietf:params:oauth:grant-type:jwt-bearer",
  );
  assertEquals(form.get("assertion")?.split(".").length, 3);
  now += TOKEN_CACHE_MS - 1;
  await client.send(MESSAGE);
  assertEquals(g.calls.oauth, 1);
  now += 1;
  await client.send(MESSAGE);
  assertEquals(g.calls.oauth, 2);
  assertEquals(g.calls.auth, [
    "Bearer tok-1",
    "Bearer tok-1",
    "Bearer tok-1",
    "Bearer tok-2",
  ]);
});

Deno.test("a 401 from FCM drops the cached token and retries once", async () => {
  const g = mockGoogle((n) =>
    n === 1 ? fcmError(401, "UNAUTHENTICATED") : Response.json({ name: "m2" })
  );
  const client = createFcmClient(SA, { fetch: g.fn, now: () => 0 });
  assertEquals(await client.send(MESSAGE), { ok: true, name: "m2" });
  assertEquals(g.calls.oauth, 2);
});

Deno.test("send reports UNREGISTERED / 404 / SENDER_ID_MISMATCH as dead tokens", async () => {
  const cases: [Response, string, boolean][] = [
    [fcmError(404, "NOT_FOUND", "UNREGISTERED"), "UNREGISTERED", true],
    [
      fcmError(403, "PERMISSION_DENIED", "SENDER_ID_MISMATCH"),
      "SENDER_ID_MISMATCH",
      true,
    ],
    [
      fcmError(400, "INVALID_ARGUMENT", "INVALID_ARGUMENT"),
      "INVALID_ARGUMENT",
      false,
    ],
    [fcmError(503, "UNAVAILABLE"), "UNAVAILABLE", false],
    [new Response("oops", { status: 500 }), "HTTP_500", false],
  ];
  for (const [res, code, invalidToken] of cases) {
    const g = mockGoogle(() => res.clone());
    const client = createFcmClient(SA, { fetch: g.fn, now: () => 0 });
    assertEquals(await client.send(MESSAGE), {
      ok: false,
      status: res.status,
      code,
      invalidToken,
    });
  }
  assertEquals(classifyFcmError(404, null), {
    code: "HTTP_404",
    invalidToken: true,
  });
});

Deno.test("OAuth or network failures come back as results, and OAuth is retried next time", async () => {
  const g = mockGoogle(() => Response.json({ name: "m" }), 400);
  const client = createFcmClient(SA, { fetch: g.fn, now: () => 0 });
  assertEquals(await client.send(MESSAGE), {
    ok: false,
    status: 0,
    code: "AUTH_FAILED",
    invalidToken: false,
  });
  await client.send(MESSAGE);
  assertEquals(g.calls.oauth, 2);
  assertEquals(g.calls.fcm, 0);

  const offline = createFcmClient(SA, {
    fetch: (input) =>
      String(input) === GOOGLE_TOKEN_URL
        ? Promise.resolve(
          Response.json({ access_token: "t", expires_in: 3600 }),
        )
        : Promise.reject(new TypeError("connection reset")),
    now: () => 0,
  });
  assertEquals(await offline.send(MESSAGE), {
    ok: false,
    status: 0,
    code: "NETWORK",
    invalidToken: false,
  });
});
