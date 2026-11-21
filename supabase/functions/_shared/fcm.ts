// FCM HTTP v1 client without npm deps (03-backend.md §7, research 05 §8): RS256 JWT signed with Web Crypto from
// the service-account JSON (Edge secret `FCM_SERVICE_ACCOUNT_JSON`, never in Git) → OAuth access token cached in
// memory for 50 min → `POST /v1/projects/<id>/messages:send`, one call per device token.

import type { FetchFn } from "./http.ts";

export const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
export const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
export const TOKEN_CACHE_MS = 50 * 60 * 1000;
const JWT_LIFETIME_S = 3600;

/** The fields we use from a Google service-account key file. */
export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri: string;
}

/** FCM v1 `message` for one device. `data` values must be strings. */
export interface FcmMessage {
  token: string;
  notification: { title: string; body: string };
  data: Record<string, string>;
  android: {
    priority: "HIGH" | "NORMAL";
    notification: { channel_id: string };
  };
}

export type FcmSendResult =
  | { ok: true; name: string }
  | { ok: false; status: number; code: string; invalidToken: boolean };

export interface FcmClient {
  readonly projectId: string;
  send(message: FcmMessage): Promise<FcmSendResult>;
}

/** The OAuth token exchange failed (bad key, revoked account, Google down). */
export class FcmAuthError extends Error {
  override name = "FcmAuthError";
}

/** Parses and checks the service-account JSON; the error never echoes the key. */
export function parseServiceAccount(json: string): ServiceAccount {
  let raw: Record<string, unknown>;
  try {
    raw = JSON.parse(json);
  } catch {
    throw new Error("FCM service account is not valid JSON");
  }
  const field = (name: string): string => {
    const v = raw?.[name];
    if (typeof v !== "string" || v.length === 0) {
      throw new Error(`FCM service account lacks ${name}`);
    }
    return v;
  };
  return {
    project_id: field("project_id"),
    client_email: field("client_email"),
    private_key: field("private_key"),
    token_uri: typeof raw.token_uri === "string" && raw.token_uri
      ? raw.token_uri
      : GOOGLE_TOKEN_URL,
  };
}

/** Base64url without padding (RFC 7515). */
export function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** DER bytes of a PKCS#8 PEM (`-----BEGIN PRIVATE KEY-----`). */
export function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const b64 = pem.replace(/-----(BEGIN|END) [A-Z ]+-----/g, "").replace(
    /\s+/g,
    "",
  );
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export function importPrivateKey(pem: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "pkcs8",
    pemToDer(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/** The signed assertion for the jwt-bearer grant: iss = client_email, aud = token_uri, 1 h lifetime. */
export async function signJwt(
  sa: ServiceAccount,
  key: CryptoKey,
  nowMs: number,
): Promise<string> {
  const iat = Math.floor(nowMs / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: FCM_SCOPE,
    aud: sa.token_uri,
    iat,
    exp: iat + JWT_LIFETIME_S,
  }));
  const input = `${header}.${claims}`;
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(input),
  );
  return `${input}.${base64url(new Uint8Array(sig))}`;
}

/**
 * The FCM error code (`error.details[].errorCode`, else `error.status`) and whether the token is dead.
 * Delete only on UNREGISTERED / HTTP 404 / SENDER_ID_MISMATCH (research 05 §8). INVALID_ARGUMENT is kept: it
 * may be our payload, and deleting every token for a payload bug would silently kill push for everyone.
 */
export function classifyFcmError(
  status: number,
  body: unknown,
): { code: string; invalidToken: boolean } {
  const error = (body as { error?: Record<string, unknown> } | null)?.error;
  let code: string | undefined;
  if (error && Array.isArray(error.details)) {
    for (const d of error.details) {
      const c = (d as Record<string, unknown> | null)?.errorCode;
      if (typeof c === "string") code = c;
    }
  }
  if (!code && typeof error?.status === "string") code = error.status;
  code ??= `HTTP_${status}`;
  const invalidToken = code === "UNREGISTERED" || status === 404 ||
    code === "SENDER_ID_MISMATCH";
  return { code, invalidToken };
}

/**
 * A client bound to one service account. The access token (and the in-flight request for it) is cached in memory,
 * so a warm isolate reuses it across calls; a 401 from FCM drops the cache and retries once.
 */
export function createFcmClient(
  sa: ServiceAccount,
  opts: { fetch: FetchFn; now: () => number },
): FcmClient {
  let keyPromise: Promise<CryptoKey> | null = null;
  let cached: { token: Promise<string>; expiresAt: number } | null = null;

  async function requestToken(): Promise<{ token: string; ttlMs: number }> {
    keyPromise ??= importPrivateKey(sa.private_key);
    const assertion = await signJwt(sa, await keyPromise, opts.now());
    const res = await opts.fetch(sa.token_uri, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }).toString(),
    });
    const body = await res.json().catch(() => null) as
      | { access_token?: unknown; expires_in?: unknown }
      | null;
    if (!res.ok || typeof body?.access_token !== "string") {
      throw new FcmAuthError(`OAuth token exchange failed: HTTP ${res.status}`);
    }
    const expiresIn = typeof body.expires_in === "number"
      ? body.expires_in
      : JWT_LIFETIME_S;
    return {
      token: body.access_token,
      ttlMs: Math.min(TOKEN_CACHE_MS, (expiresIn - 60) * 1000),
    };
  }

  function accessToken(): Promise<string> {
    const now = opts.now();
    if (cached && now < cached.expiresAt) return cached.token;
    const entry = {
      token: Promise.resolve(""),
      expiresAt: now + TOKEN_CACHE_MS,
    };
    entry.token = requestToken().then(
      ({ token, ttlMs }) => {
        entry.expiresAt = now + ttlMs;
        return token;
      },
      (e) => {
        if (cached === entry) cached = null;
        throw e;
      },
    );
    cached = entry;
    return entry.token;
  }

  const endpoint = `https://fcm.googleapis.com/v1/projects/${
    encodeURIComponent(sa.project_id)
  }/messages:send`;

  async function attempt(
    message: FcmMessage,
    retried: boolean,
  ): Promise<FcmSendResult> {
    let token: string;
    try {
      token = await accessToken();
    } catch (e) {
      console.error("fcm auth", (e as Error).message);
      return { ok: false, status: 0, code: "AUTH_FAILED", invalidToken: false };
    }
    let res: Response;
    try {
      res = await opts.fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message }),
      });
    } catch {
      return { ok: false, status: 0, code: "NETWORK", invalidToken: false };
    }
    const body = await res.json().catch(() => null);
    if (res.ok) {
      return {
        ok: true,
        name: String((body as { name?: unknown })?.name ?? ""),
      };
    }
    if (res.status === 401 && !retried) {
      cached = null;
      return attempt(message, true);
    }
    return {
      ok: false,
      status: res.status,
      ...classifyFcmError(res.status, body),
    };
  }

  return {
    projectId: sa.project_id,
    send: (message) => attempt(message, false),
  };
}
