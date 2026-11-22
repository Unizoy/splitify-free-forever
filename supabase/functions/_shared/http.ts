// Small HTTP helpers shared by every Edge Function (planning/03-backend.md §7).

/** Standard JSON headers. The app is Android-only, so no CORS headers are needed. */
export const jsonHeaders: Record<string, string> = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

/** A JSON response with the given status (default 200). */
export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

/**
 * An error response `{ "error": code, "message"?: message }`. Codes are stable machine-readable strings
 * (e.g. `NOT_AUTHENTICATED`); messages are for logs only and never contain secrets.
 */
export function errorResponse(
  code: string,
  status: number,
  message?: string,
): Response {
  if (status < 400 || status > 599) {
    throw new RangeError(`error status must be 4xx/5xx, got ${status}`);
  }
  return jsonResponse(
    message ? { error: code, message } : { error: code },
    status,
  );
}

/** Only the given HTTP methods are allowed; returns a 405 response otherwise, else null. */
export function requireMethod(
  req: Request,
  ...methods: string[]
): Response | null {
  if (methods.includes(req.method)) return null;
  const res = errorResponse("METHOD_NOT_ALLOWED", 405);
  res.headers.set("Allow", methods.join(", "));
  return res;
}

/** The `fetch` signature, injected into function logic so tests can mock every network call. */
export type FetchFn = typeof fetch;

/** Largest request body the functions accept (their bodies are one small JSON object). */
export const MAX_BODY_BYTES = 4096;

export type BodyResult =
  | { ok: true; value: unknown }
  | { ok: false; response: Response };

/**
 * Reads a JSON request body of at most `maxBytes` (default 4 KB) without buffering more than that.
 * 413 PAYLOAD_TOO_LARGE for a bigger body (declared or streamed), 400 INVALID_BODY for an empty or non-JSON one.
 */
export async function readJsonBody(
  req: Request,
  maxBytes = MAX_BODY_BYTES,
): Promise<BodyResult> {
  const tooLarge = (): BodyResult => ({
    ok: false,
    response: errorResponse("PAYLOAD_TOO_LARGE", 413),
  });
  const declared = Number(req.headers.get("Content-Length") ?? "0");
  if (Number.isFinite(declared) && declared > maxBytes) {
    await req.body?.cancel().catch(() => undefined);
    return tooLarge();
  }
  const chunks: Uint8Array[] = [];
  let size = 0;
  const reader = req.body?.getReader();
  try {
    while (reader) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBytes) {
        await reader.cancel().catch(() => undefined);
        return tooLarge();
      }
      chunks.push(value);
    }
  } catch {
    return {
      ok: false,
      response: errorResponse("INVALID_BODY", 400, "body unreadable"),
    };
  }
  const bytes = new Uint8Array(size);
  let at = 0;
  for (const c of chunks) {
    bytes.set(c, at);
    at += c.byteLength;
  }
  try {
    return { ok: true, value: JSON.parse(new TextDecoder().decode(bytes)) };
  } catch {
    return {
      ok: false,
      response: errorResponse("INVALID_BODY", 400, "body must be JSON"),
    };
  }
}
