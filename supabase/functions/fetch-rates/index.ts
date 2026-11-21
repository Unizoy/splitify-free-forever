// Edge Function `fetch-rates` (verify_jwt = false). Called by pg_cron via pg_net (03-backend.md §6).
// Wiring only: the logic and its tests live in rates.ts / rates_test.ts.

import { createClient } from "npm:@supabase/supabase-js@2";
import { adminCredentials } from "../_shared/admin_client.ts";
import { type FxRateRow, handleFetchRates, type RatesDb } from "./rates.ts";

function supabaseRatesDb(): RatesDb {
  const { url, key } = adminCredentials((name) => Deno.env.get(name));
  const sb = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return {
    async latestFetchedAt() {
      const { data, error } = await sb.from("fx_rates").select("fetched_at")
        .order("fetched_at", { ascending: false }).limit(1).maybeSingle();
      if (error) throw new Error(`fx_rates read: ${error.message}`);
      return data ? new Date(data.fetched_at as string) : null;
    },
    async frankfurterCurrencies() {
      const { data, error } = await sb.from("currencies").select("code").eq(
        "frankfurter",
        true,
      );
      if (error) throw new Error(`currencies read: ${error.message}`);
      return (data ?? []).map((r) => String(r.code).trim());
    },
    async upsertRates(rows: FxRateRow[]) {
      const { error } = await sb.from("fx_rates").upsert(rows, {
        onConflict: "date,currency",
      });
      if (error) throw new Error(`fx_rates upsert: ${error.message}`);
    },
  };
}

Deno.serve((req) =>
  handleFetchRates(req, {
    db: supabaseRatesDb(),
    fetch,
    now: () => new Date(),
  })
);
