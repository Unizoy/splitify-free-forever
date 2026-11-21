import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { adminCredentials } from "./admin_client.ts";

const envOf = (vars: Record<string, string>) => (name: string) => vars[name];

Deno.test("adminCredentials prefers the default entry of SUPABASE_SECRET_KEYS", () => {
  const env = envOf({
    SUPABASE_URL: "https://x.supabase.co",
    SUPABASE_SECRET_KEYS: JSON.stringify({ other: "k2", default: "k1" }),
    SUPABASE_SERVICE_ROLE_KEY: "legacy",
  });
  assertEquals(adminCredentials(env), {
    url: "https://x.supabase.co",
    key: "k1",
  });
});

Deno.test("adminCredentials takes the first named key when there is no default", () => {
  const env = envOf({
    SUPABASE_URL: "u",
    SUPABASE_SECRET_KEYS: JSON.stringify({ cron: "k9" }),
  });
  assertEquals(adminCredentials(env).key, "k9");
});

Deno.test("adminCredentials falls back to the legacy service role key", () => {
  const env = envOf({
    SUPABASE_URL: "u",
    SUPABASE_SECRET_KEYS: "not json",
    SUPABASE_SERVICE_ROLE_KEY: "legacy",
  });
  assertEquals(adminCredentials(env).key, "legacy");
});

Deno.test("adminCredentials throws without URL or key", () => {
  assertThrows(() => adminCredentials(envOf({})), Error, "SUPABASE_URL");
  assertThrows(
    () => adminCredentials(envOf({ SUPABASE_URL: "u" })),
    Error,
    "secret key",
  );
});
