import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { errorResponse, jsonResponse, requireMethod } from "./http.ts";

Deno.test("jsonResponse serialises the body with JSON headers", async () => {
  const res = jsonResponse({ ok: true, amount: 10050 });
  assertEquals(res.status, 200);
  assertEquals(
    res.headers.get("Content-Type"),
    "application/json; charset=utf-8",
  );
  assertEquals(res.headers.get("Cache-Control"), "no-store");
  assertEquals(await res.json(), { ok: true, amount: 10050 });
});

Deno.test("jsonResponse keeps a custom status", () => {
  assertEquals(jsonResponse({}, 202).status, 202);
});

Deno.test("errorResponse carries the code and optional message", async () => {
  const bare = errorResponse("NOT_AUTHENTICATED", 401);
  assertEquals(bare.status, 401);
  assertEquals(await bare.json(), { error: "NOT_AUTHENTICATED" });
  const withMessage = errorResponse(
    "UPSTREAM_FAILED",
    502,
    "frankfurter timeout",
  );
  assertEquals(await withMessage.json(), {
    error: "UPSTREAM_FAILED",
    message: "frankfurter timeout",
  });
});

Deno.test("errorResponse rejects non-error statuses", () => {
  assertThrows(() => errorResponse("X", 200), RangeError);
});

Deno.test("requireMethod allows listed methods and answers 405 otherwise", async () => {
  assertEquals(
    requireMethod(new Request("http://x", { method: "POST" }), "POST"),
    null,
  );
  const res = requireMethod(
    new Request("http://x", { method: "GET" }),
    "POST",
    "OPTIONS",
  );
  assertEquals(res?.status, 405);
  assertEquals(res?.headers.get("Allow"), "POST, OPTIONS");
  assertEquals(await res?.json(), { error: "METHOD_NOT_ALLOWED" });
});
