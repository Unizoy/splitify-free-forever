// Entry point; deploy with JWT verification on (default): `supabase functions deploy delete-account`.
import { createHandler } from "./handler.ts";

Deno.serve(createHandler({
  fetch: (input, init) => fetch(input, init),
  env: (name) => Deno.env.get(name),
}));
