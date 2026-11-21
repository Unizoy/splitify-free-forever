// fetch-rates logic (03-backend.md §6, phase 14 T2). Pure apart from the injected fetch, clock and DB.
//
// Frankfurter v2 (verified with curl 2026-11-21): GET /v2/rates?base=EUR[&from=YYYY-MM-DD&to=YYYY-MM-DD]
// → 200 `[{ "date": "2026-11-21", "base": "EUR", "quote": "INR", "rate": 102.12 }, ...]`; unknown codes in
// `quotes` give 422 `{ status, message }`, so we never send `quotes` and filter by our own currency list.

import {
  errorResponse,
  type FetchFn,
  jsonResponse,
  requireMethod,
} from "../_shared/http.ts";

export const FRANKFURTER_RATES_URL = "https://api.frankfurter.dev/v2/rates";
/** Cron runs twice a day; any call within 6 h of the last fetch is a no-op (T-016). */
export const THROTTLE_MS = 6 * 60 * 60 * 1000;
/** An empty `fx_rates` table is filled with the last 30 days first. */
export const BACKFILL_DAYS = 30;
/** Rows per upsert call (PostgREST request size). */
export const UPSERT_CHUNK = 500;
export const SOURCE = "frankfurter";

/** One `fx_rates` row: `rate` = units of `currency` per 1 EUR, as exact decimal text (never a float column). */
export interface FxRateRow {
  date: string;
  currency: string;
  rate: string;
  source: typeof SOURCE;
  fetched_at: string;
}

/** The only database access fetch-rates needs; index.ts implements it with supabase-js. */
export interface RatesDb {
  /** `max(fetched_at)` of `fx_rates`, or null when the table is empty. */
  latestFetchedAt(): Promise<Date | null>;
  /** `select code from currencies where frankfurter`. */
  frankfurterCurrencies(): Promise<string[]>;
  /** Upsert on `(date, currency)`, updating rate, source and fetched_at. */
  upsertRates(rows: FxRateRow[]): Promise<void>;
}

export interface FetchRatesDeps {
  db: RatesDb;
  fetch: FetchFn;
  now: () => Date;
}

export type FetchRatesResult =
  | { status: "throttled"; last_fetched_at: string }
  | { status: "no_currencies" }
  | {
    status: "ok";
    mode: "latest" | "backfill";
    rows: number;
    first_date: string | null;
    last_date: string | null;
  };

/** Frankfurter answered with something we can't use. */
export class UpstreamError extends Error {
  override name = "UpstreamError";
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const CODE_RE = /^[A-Z]{3}$/;

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/** The request URL: latest rates, or a `from`/`to` range for the first-run backfill (UTC dates). */
export function frankfurterUrl(now: Date, backfill: boolean): string {
  const url = new URL(FRANKFURTER_RATES_URL);
  url.searchParams.set("base", "EUR");
  if (backfill) {
    const from = new Date(now.getTime() - BACKFILL_DAYS * 24 * 60 * 60 * 1000);
    url.searchParams.set("from", isoDate(from));
    url.searchParams.set("to", isoDate(now));
  }
  return url.toString();
}

/**
 * A JSON rate as plain decimal text that fits `numeric(24,10)`, or null if it is not a usable rate.
 * Rates are ratios, not money (rule 1 is about amounts); Postgres rounds anything past 10 decimals.
 */
export function rateText(rate: unknown): string | null {
  if (typeof rate !== "number" || !Number.isFinite(rate) || rate <= 0) {
    return null;
  }
  if (rate >= 1e14) return null;
  let text = String(rate);
  if (text.includes("e")) {
    text = rate.toFixed(10).replace(/\.?0+$/, "");
    if (text === "0") return null;
  }
  return text;
}

/**
 * Valid EUR-based entries for the allowed currencies, one per (date, currency) (a duplicate would make the
 * upsert fail). EUR itself gets rate 1 on every returned date, so `rate(A→B) = eur[B] / eur[A]` needs no
 * special case (05-money-engine.md §6).
 */
export function parseRates(
  body: unknown,
  allowed: ReadonlySet<string>,
): { date: string; currency: string; rate: string }[] {
  if (!Array.isArray(body)) {
    throw new UpstreamError("Frankfurter response is not an array");
  }
  const byKey = new Map<
    string,
    { date: string; currency: string; rate: string }
  >();
  const dates = new Set<string>();
  for (const item of body) {
    if (typeof item !== "object" || item === null) continue;
    const { date, base, quote, rate } = item as Record<string, unknown>;
    if (base !== "EUR" || typeof date !== "string" || !DATE_RE.test(date)) {
      continue;
    }
    if (typeof quote !== "string" || !CODE_RE.test(quote)) continue;
    if (quote === "EUR" || !allowed.has(quote)) continue;
    const text = rateText(rate);
    if (text === null) continue;
    byKey.set(`${date}|${quote}`, { date, currency: quote, rate: text });
    dates.add(date);
  }
  if (allowed.has("EUR")) {
    for (const date of dates) {
      byKey.set(`${date}|EUR`, { date, currency: "EUR", rate: "1" });
    }
  }
  return [...byKey.values()].sort((a, b) =>
    a.date === b.date
      ? a.currency.localeCompare(b.currency)
      : a.date.localeCompare(b.date)
  );
}

/** One run: throttle check → GET Frankfurter → upsert. Safe to call any number of times. */
export async function fetchRates(
  deps: FetchRatesDeps,
): Promise<FetchRatesResult> {
  const now = deps.now();
  const last = await deps.db.latestFetchedAt();
  if (last && now.getTime() - last.getTime() < THROTTLE_MS) {
    return { status: "throttled", last_fetched_at: last.toISOString() };
  }
  const codes = await deps.db.frankfurterCurrencies();
  if (codes.length === 0) return { status: "no_currencies" };

  const backfill = last === null;
  let res: Response;
  try {
    res = await deps.fetch(frankfurterUrl(now, backfill), {
      headers: { Accept: "application/json" },
    });
  } catch (e) {
    throw new UpstreamError(
      `Frankfurter request failed: ${(e as Error).message}`,
    );
  }
  if (!res.ok) {
    await res.body?.cancel();
    throw new UpstreamError(`Frankfurter answered HTTP ${res.status}`);
  }
  let body: unknown;
  try {
    body = await res.json();
  } catch {
    throw new UpstreamError("Frankfurter response is not JSON");
  }

  const fetchedAt = now.toISOString();
  const rows: FxRateRow[] = parseRates(body, new Set(codes)).map((r) => ({
    ...r,
    source: SOURCE,
    fetched_at: fetchedAt,
  }));
  for (let i = 0; i < rows.length; i += UPSERT_CHUNK) {
    await deps.db.upsertRates(rows.slice(i, i + UPSERT_CHUNK));
  }
  return {
    status: "ok",
    mode: backfill ? "backfill" : "latest",
    rows: rows.length,
    first_date: rows.length ? rows[0].date : null,
    last_date: rows.length ? rows[rows.length - 1].date : null,
  };
}

/** HTTP wrapper: POST only (pg_net / cron); verify_jwt is false because the run is idempotent and throttled. */
export async function handleFetchRates(
  req: Request,
  deps: FetchRatesDeps,
): Promise<Response> {
  const notAllowed = requireMethod(req, "POST");
  if (notAllowed) return notAllowed;
  try {
    const result = await fetchRates(deps);
    console.log("fetch-rates", JSON.stringify(result));
    return jsonResponse(result);
  } catch (e) {
    if (e instanceof UpstreamError) {
      console.error("fetch-rates upstream", e.message);
      return errorResponse("UPSTREAM_FAILED", 502, e.message);
    }
    console.error("fetch-rates failed", (e as Error).message);
    return errorResponse("INTERNAL", 500);
  }
}
