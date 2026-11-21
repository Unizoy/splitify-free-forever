// Credentials for the server-side Supabase client used by cron/trigger-called functions (03-backend.md §7).
// Pure: the caller passes an env reader, so tests never touch Deno.env and no key is ever logged.

/** What `createClient(url, key)` needs to act as the service role (bypasses RLS). */
export interface AdminCredentials {
  url: string;
  key: string;
}

/**
 * Reads `SUPABASE_URL` and the secret key. Prefers the 2026 `SUPABASE_SECRET_KEYS` JSON dict (`default` entry,
 * else its first key), falls back to the legacy `SUPABASE_SERVICE_ROLE_KEY` (research 05 §2).
 */
export function adminCredentials(
  env: (name: string) => string | undefined,
): AdminCredentials {
  const url = env("SUPABASE_URL");
  if (!url) throw new Error("SUPABASE_URL is not set");
  const dict = env("SUPABASE_SECRET_KEYS");
  if (dict) {
    try {
      const keys = JSON.parse(dict) as Record<string, unknown>;
      const preferred = keys["default"];
      if (typeof preferred === "string" && preferred) {
        return { url, key: preferred };
      }
      const first = Object.values(keys).find(
        (v): v is string => typeof v === "string" && v.length > 0,
      );
      if (first) return { url, key: first };
    } catch {
      // Malformed dict: try the legacy key below.
    }
  }
  const legacy = env("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return { url, key: legacy };
  throw new Error("no Supabase secret key in the environment");
}
