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
