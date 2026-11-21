// TC-B1-05 delete-account: caller from the JWT only, memberships converted (RPC), avatars removed, user deleted.
import { assertEquals } from "jsr:@std/assert@1";
import { createHandler, type FetchFn } from "./handler.ts";

const BASE = "https://proj.supabase.co";
const UID = "00000000-0000-4000-8000-0000000000a1";
const OTHER = "00000000-0000-4000-8000-0000000000b1";
const ENV: Record<string, string> = {
  SUPABASE_URL: `${BASE}/`,
  SUPABASE_ANON_KEY: "anon-key",
  SUPABASE_SERVICE_ROLE_KEY: "service-key",
};

interface Call {
  method: string;
  url: string;
  headers: Headers;
  body: unknown;
}

type Route = (call: Call) => Response;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status });

/** Happy-path upstream; `overrides` replace the answer for a "METHOD path" key. */
function upstream(overrides: Record<string, Route> = {}) {
  const calls: Call[] = [];
  const routes: Record<string, Route> = {
    "GET /auth/v1/user": () => json({ id: UID, email: "a@x.test" }),
    "POST /rest/v1/rpc/prepare_account_deletion": () =>
      json({ avatar_path: `${UID}/me.jpg`, groups: 2 }),
    "POST /storage/v1/object/list/avatars": () =>
      json([
        { name: "me.jpg", id: "f1" },
        { name: "old.jpg", id: "f2" },
      ]),
    "DELETE /storage/v1/object/avatars": () => json([]),
    [`DELETE /auth/v1/admin/users/${UID}`]: () => json({}),
    ...overrides,
  };
  const fetch: FetchFn = (input, init) => {
    const method = init?.method ?? "GET";
    const call: Call = {
      method,
      url: input,
      headers: new Headers(init?.headers),
      body: typeof init?.body === "string" ? JSON.parse(init.body) : undefined,
    };
    calls.push(call);
    const route = routes[`${method} ${new URL(input).pathname}`];
    return Promise.resolve(route ? route(call) : json({}, 404));
  };
  return { calls, fetch };
}

function handler(
  fetch: FetchFn,
  env: Record<string, string | undefined> = ENV,
) {
  return createHandler({ fetch, env: (name) => env[name] });
}

function post(body: unknown = {}, auth: string | null = "Bearer user-jwt") {
  const headers = new Headers({ "Content-Type": "application/json" });
  if (auth !== null) headers.set("Authorization", auth);
  return new Request("http://localhost/delete-account", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

Deno.test("deletes the account in order, as the JWT's user only", async () => {
  const up = upstream();
  // A body naming another user must be ignored.
  const res = await handler(up.fetch)(post({ user_id: OTHER, id: OTHER }));
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { deleted: true });

  assertEquals(up.calls.map((c) => `${c.method} ${c.url}`), [
    `GET ${BASE}/auth/v1/user`,
    `POST ${BASE}/rest/v1/rpc/prepare_account_deletion`,
    `POST ${BASE}/storage/v1/object/list/avatars`,
    `DELETE ${BASE}/storage/v1/object/avatars`,
    `DELETE ${BASE}/auth/v1/admin/users/${UID}`,
  ]);
  const [lookup, rpc, list, remove, deleteUser] = up.calls;

  // User-scoped calls carry the caller's JWT and the anon key.
  for (const c of [lookup, rpc]) {
    assertEquals(c.headers.get("Authorization"), "Bearer user-jwt");
    assertEquals(c.headers.get("apikey"), "anon-key");
  }
  assertEquals(rpc.body, {});
  // Admin calls use the service key, never the user's JWT.
  for (const c of [list, remove, deleteUser]) {
    assertEquals(c.headers.get("Authorization"), "Bearer service-key");
    assertEquals(c.headers.get("apikey"), "service-key");
  }
  assertEquals(
    (list.body as { prefix: string }).prefix,
    `${UID}/`,
  );
  assertEquals(remove.body, { prefixes: [`${UID}/me.jpg`, `${UID}/old.jpg`] });
  assertEquals(
    up.calls.some((c) =>
      c.url.includes(OTHER) || JSON.stringify(c.body ?? null).includes(OTHER)
    ),
    false,
  );
});

Deno.test("skips the storage delete when the user has no avatar files", async () => {
  const up = upstream({
    "POST /storage/v1/object/list/avatars": () =>
      json([{ name: "sub", id: null }]),
  });
  const res = await handler(up.fetch)(post());
  assertEquals(res.status, 200);
  assertEquals(up.calls.map((c) => c.method + " " + new URL(c.url).pathname), [
    "GET /auth/v1/user",
    "POST /rest/v1/rpc/prepare_account_deletion",
    "POST /storage/v1/object/list/avatars",
    `DELETE /auth/v1/admin/users/${UID}`,
  ]);
});

Deno.test("only POST is allowed", async () => {
  const up = upstream();
  const res = await handler(up.fetch)(
    new Request("http://localhost/delete-account", { method: "GET" }),
  );
  assertEquals(res.status, 405);
  assertEquals(res.headers.get("Allow"), "POST");
  assertEquals(await res.json(), { error: "METHOD_NOT_ALLOWED" });
  assertEquals(up.calls.length, 0);
});

Deno.test("missing env answers 500 MISCONFIGURED without calling out", async () => {
  for (const name of Object.keys(ENV)) {
    const up = upstream();
    const res = await handler(up.fetch, { ...ENV, [name]: undefined })(post());
    assertEquals(res.status, 500, name);
    assertEquals(await res.json(), { error: "MISCONFIGURED" });
    assertEquals(up.calls.length, 0);
  }
});

Deno.test("missing or malformed Authorization answers 401", async () => {
  for (const auth of [null, "", "Basic abc", "Bearer", "Bearer a b"]) {
    const up = upstream();
    const res = await handler(up.fetch)(post({}, auth));
    assertEquals(res.status, 401, String(auth));
    assertEquals(await res.json(), { error: "NOT_AUTHENTICATED" });
    assertEquals(up.calls.length, 0);
  }
});

Deno.test("a JWT the auth server rejects answers 401 and changes nothing", async () => {
  for (
    const route of [
      () => json({ msg: "invalid JWT" }, 401),
      () => json({ id: "not-a-uuid" }),
      () => new Response("not json"),
    ]
  ) {
    const up = upstream({ "GET /auth/v1/user": route });
    const res = await handler(up.fetch)(post({ user_id: UID }));
    assertEquals(res.status, 401);
    assertEquals(await res.json(), { error: "NOT_AUTHENTICATED" });
    assertEquals(up.calls.length, 1);
  }
});

Deno.test("upstream failures answer 502 <STEP>_FAILED and stop", async () => {
  const cases: [string, string, number][] = [
    ["GET /auth/v1/user", "USER_LOOKUP_FAILED", 1],
    ["POST /rest/v1/rpc/prepare_account_deletion", "PREPARE_FAILED", 2],
    ["POST /storage/v1/object/list/avatars", "AVATAR_LIST_FAILED", 3],
    ["DELETE /storage/v1/object/avatars", "AVATAR_DELETE_FAILED", 4],
    [`DELETE /auth/v1/admin/users/${UID}`, "USER_DELETE_FAILED", 5],
  ];
  for (const [key, code, callCount] of cases) {
    const up = upstream({ [key]: () => json({ message: "boom" }, 500) });
    const res = await handler(up.fetch)(post());
    assertEquals(res.status, 502, key);
    assertEquals(await res.json(), { error: code });
    assertEquals(up.calls.length, callCount, key);
  }
});

Deno.test("network errors and bad list bodies answer 502", async () => {
  const up = upstream({
    "POST /rest/v1/rpc/prepare_account_deletion": () => {
      throw new TypeError("connection reset");
    },
  });
  const res = await handler(up.fetch)(post());
  assertEquals(res.status, 502);
  assertEquals(await res.json(), { error: "PREPARE_FAILED" });

  const lookupDown = upstream({
    "GET /auth/v1/user": () => {
      throw new TypeError("dns");
    },
  });
  const res2 = await handler(lookupDown.fetch)(post());
  assertEquals(res2.status, 502);
  assertEquals(await res2.json(), { error: "USER_LOOKUP_FAILED" });

  const badList = upstream({
    "POST /storage/v1/object/list/avatars": () => json({ not: "a list" }),
  });
  const res3 = await handler(badList.fetch)(post());
  assertEquals(res3.status, 502);
  assertEquals(await res3.json(), { error: "AVATAR_LIST_FAILED" });
  assertEquals(badList.calls.length, 3);
});
