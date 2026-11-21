import {
  assert,
  assertEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert@1";
import {
  fetchRates,
  frankfurterUrl,
  type FxRateRow,
  handleFetchRates,
  parseRates,
  type RatesDb,
  rateText,
  THROTTLE_MS,
  UPSERT_CHUNK,
  UpstreamError,
} from "./rates.ts";
import type { FetchFn } from "../_shared/http.ts";

const NOW = new Date("2026-11-21T01:15:00Z");

/** In-memory fx_rates keyed by (date, currency), like the real upsert. */
class FakeDb implements RatesDb {
  rows = new Map<string, FxRateRow>();
  upsertCalls: number[] = [];
  constructor(public codes: string[] = ["EUR", "INR", "USD", "AED"]) {}
  latestFetchedAt(): Promise<Date | null> {
    let max: string | null = null;
    for (const r of this.rows.values()) {
      if (max === null || r.fetched_at > max) max = r.fetched_at;
    }
    return Promise.resolve(max ? new Date(max) : null);
  }
  frankfurterCurrencies(): Promise<string[]> {
    return Promise.resolve(this.codes);
  }
  upsertRates(rows: FxRateRow[]): Promise<void> {
    this.upsertCalls.push(rows.length);
    for (const r of rows) this.rows.set(`${r.date}|${r.currency}`, r);
    return Promise.resolve();
  }
}

/** Fetch mock: records URLs, answers with the given JSON body and status. No network in tests. */
function mockFetch(body: unknown, status = 200) {
  const urls: string[] = [];
  const fn: FetchFn = (input) => {
    urls.push(String(input));
    return Promise.resolve(
      new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" },
      }),
    );
  };
  return { fn, urls };
}

const latest = [
  { date: "2026-11-21", base: "EUR", quote: "INR", rate: 102.12 },
  { date: "2026-11-21", base: "EUR", quote: "USD", rate: 1.0989 },
  { date: "2026-11-20", base: "EUR", quote: "AED", rate: 4.0351 },
  { date: "2026-11-21", base: "EUR", quote: "BTC", rate: 0.0000105 },
];

Deno.test("frankfurterUrl asks v2 for EUR-based latest rates, or a 30-day range on backfill", () => {
  assertEquals(
    frankfurterUrl(NOW, false),
    "https://api.frankfurter.dev/v2/rates?base=EUR",
  );
  assertEquals(
    frankfurterUrl(NOW, true),
    "https://api.frankfurter.dev/v2/rates?base=EUR&from=2026-10-22&to=2026-11-21",
  );
});

Deno.test("rateText keeps exact decimal text and rejects unusable rates", () => {
  assertEquals(rateText(102.12), "102.12");
  assertEquals(rateText(26150), "26150");
  assertEquals(rateText(1.5e-7), "0.00000015");
  assertEquals(rateText(1e-12), null);
  assertEquals(rateText(0), null);
  assertEquals(rateText(-1), null);
  assertEquals(rateText(Number.NaN), null);
  assertEquals(rateText("1.2"), null);
  assertEquals(rateText(1e15), null);
});

Deno.test("parseRates keeps allowed currencies, stores the returned date per rate, adds EUR = 1", () => {
  const rows = parseRates(latest, new Set(["EUR", "INR", "USD", "AED"]));
  assertEquals(rows, [
    { date: "2026-11-20", currency: "AED", rate: "4.0351" },
    { date: "2026-11-20", currency: "EUR", rate: "1" },
    { date: "2026-11-21", currency: "EUR", rate: "1" },
    { date: "2026-11-21", currency: "INR", rate: "102.12" },
    { date: "2026-11-21", currency: "USD", rate: "1.0989" },
  ]);
});

Deno.test("parseRates skips malformed entries and de-duplicates (date, currency)", () => {
  const rows = parseRates(
    [
      null,
      "x",
      { date: "2026-11-21", base: "USD", quote: "INR", rate: 84 },
      { date: "21-11-2026", base: "EUR", quote: "INR", rate: 1 },
      { date: "2026-11-21", base: "EUR", quote: "inr", rate: 1 },
      { date: "2026-11-21", base: "EUR", quote: "INR", rate: "102" },
      { date: "2026-11-21", base: "EUR", quote: "INR", rate: 101 },
      { date: "2026-11-21", base: "EUR", quote: "INR", rate: 102.5 },
      { date: "2026-11-21", base: "EUR", quote: "EUR", rate: 3 },
    ],
    new Set(["INR"]),
  );
  assertEquals(rows, [{ date: "2026-11-21", currency: "INR", rate: "102.5" }]);
  assertThrows(() => parseRates({ status: 422 }, new Set()), UpstreamError);
});

Deno.test("first run on an empty table backfills 30 days", async () => {
  const db = new FakeDb();
  const { fn, urls } = mockFetch(latest);
  const result = await fetchRates({ db, fetch: fn, now: () => NOW });
  assertEquals(result, {
    status: "ok",
    mode: "backfill",
    rows: 5,
    first_date: "2026-11-20",
    last_date: "2026-11-21",
  });
  assertEquals(urls.length, 1);
  assert(urls[0].includes("from=2026-10-22&to=2026-11-21"));
  const inr = db.rows.get("2026-11-21|INR");
  assertEquals(inr, {
    date: "2026-11-21",
    currency: "INR",
    rate: "102.12",
    source: "frankfurter",
    fetched_at: NOW.toISOString(),
  });
});

Deno.test("a call within 6 h is throttled and makes no request", async () => {
  const db = new FakeDb();
  await fetchRates({ db, fetch: mockFetch(latest).fn, now: () => NOW });
  const again = mockFetch(latest);
  const soon = new Date(NOW.getTime() + THROTTLE_MS - 1);
  const result = await fetchRates({ db, fetch: again.fn, now: () => soon });
  assertEquals(result, {
    status: "throttled",
    last_fetched_at: NOW.toISOString(),
  });
  assertEquals(again.urls.length, 0);
});

Deno.test("later runs fetch latest only and are idempotent per (date, currency)", async () => {
  const db = new FakeDb();
  await fetchRates({ db, fetch: mockFetch(latest).fn, now: () => NOW });
  const later = new Date(NOW.getTime() + THROTTLE_MS);
  const second = mockFetch(latest);
  const result = await fetchRates({ db, fetch: second.fn, now: () => later });
  assertEquals(result.status === "ok" && result.mode, "latest");
  assertEquals(second.urls, ["https://api.frankfurter.dev/v2/rates?base=EUR"]);
  assertEquals(db.rows.size, 5);
  assertEquals(db.rows.get("2026-11-21|INR")?.fetched_at, later.toISOString());
});

Deno.test("no frankfurter currencies means no request", async () => {
  const db = new FakeDb([]);
  const { fn, urls } = mockFetch(latest);
  assertEquals(await fetchRates({ db, fetch: fn, now: () => NOW }), {
    status: "no_currencies",
  });
  assertEquals(urls.length, 0);
});

Deno.test("upserts are chunked", async () => {
  const codes = ["EUR", "INR"];
  const body = [];
  for (let d = 1; d <= 400; d++) {
    const date = new Date(Date.UTC(2025, 0, d)).toISOString().slice(0, 10);
    body.push({ date, base: "EUR", quote: "INR", rate: 90 + d / 100 });
  }
  const db = new FakeDb(codes);
  const result = await fetchRates({
    db,
    fetch: mockFetch(body).fn,
    now: () => NOW,
  });
  assertEquals(result.status === "ok" && result.rows, 800);
  assertEquals(db.upsertCalls, [UPSERT_CHUNK, 800 - UPSERT_CHUNK]);
});

Deno.test("upstream errors raise UpstreamError and write nothing", async () => {
  const db = new FakeDb();
  await assertRejects(
    () =>
      fetchRates({
        db,
        fetch: mockFetch({ status: 422, message: "x" }, 422).fn,
        now: () => NOW,
      }),
    UpstreamError,
    "HTTP 422",
  );
  const broken: FetchFn = () => Promise.resolve(new Response("<html>"));
  await assertRejects(
    () => fetchRates({ db, fetch: broken, now: () => NOW }),
    UpstreamError,
    "not JSON",
  );
  const offline: FetchFn = () => Promise.reject(new TypeError("dns"));
  await assertRejects(
    () => fetchRates({ db, fetch: offline, now: () => NOW }),
    UpstreamError,
    "dns",
  );
  assertEquals(db.rows.size, 0);
});

Deno.test("handleFetchRates: POST only, JSON result, 502 on upstream, 500 on DB errors", async () => {
  const deps = {
    db: new FakeDb(),
    fetch: mockFetch(latest).fn,
    now: () => NOW,
  };
  const get = await handleFetchRates(new Request("http://x"), deps);
  assertEquals(get.status, 405);
  await get.body?.cancel();

  const ok = await handleFetchRates(
    new Request("http://x", { method: "POST" }),
    deps,
  );
  assertEquals(ok.status, 200);
  assertEquals((await ok.json()).status, "ok");

  const bad = await handleFetchRates(
    new Request("http://x", { method: "POST" }),
    { ...deps, db: new FakeDb(), fetch: mockFetch([], 503).fn },
  );
  assertEquals(bad.status, 502);
  assertEquals((await bad.json()).error, "UPSTREAM_FAILED");

  const failingDb = new FakeDb();
  failingDb.latestFetchedAt = () => Promise.reject(new Error("db down"));
  const broken = await handleFetchRates(
    new Request("http://x", { method: "POST" }),
    { ...deps, db: failingDb },
  );
  assertEquals(broken.status, 500);
  assertEquals(await broken.json(), { error: "INTERNAL" });
});
