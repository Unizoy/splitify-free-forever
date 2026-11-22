import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  errorResponse,
  jsonResponse,
  readJsonBody,
  requireMethod,
} from "./http.ts";

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

Deno.test("readJsonBody parses a small JSON body", async () => {
  const r = await readJsonBody(
    new Request("http://x", { method: "POST", body: '{"a":1}' }),
  );
  assertEquals(r.ok, true);
  assertEquals(r.ok && r.value, { a: 1 });
});

Deno.test("readJsonBody answers 400 INVALID_BODY for empty, non-JSON and truncated bodies", async () => {
  for (const body of [undefined, "", "nope", '{"a":', "\u0000"]) {
    const r = await readJsonBody(
      new Request("http://x", { method: "POST", body }),
    );
    assertEquals(r.ok, false);
    if (!r.ok) {
      assertEquals(r.response.status, 400);
      assertEquals((await r.response.json()).error, "INVALID_BODY");
    }
  }
});

Deno.test("readJsonBody answers 413 for a body over the limit, declared or streamed", async () => {
  const big = JSON.stringify({ pad: "x".repeat(5000) });
  const declared = await readJsonBody(
    new Request("http://x", { method: "POST", body: big }),
  );
  assertEquals(!declared.ok && declared.response.status, 413);
  // No Content-Length: a chunked stream is cut off at the limit.
  const stream = new ReadableStream<Uint8Array>({
    pull(c) {
      c.enqueue(new TextEncoder().encode("x".repeat(1024)));
    },
  });
  const streamed = await readJsonBody(
    new Request(
      "http://x",
      { method: "POST", body: stream, duplex: "half" } as RequestInit,
    ),
  );
  assertEquals(!streamed.ok && streamed.response.status, 413);
  assertEquals(
    !streamed.ok && (await streamed.response.json()).error,
    "PAYLOAD_TOO_LARGE",
  );
  const ok = await readJsonBody(
    new Request("http://x", { method: "POST", body: big }),
    10000,
  );
  assertEquals(ok.ok, true);
});
