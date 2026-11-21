// delete-account (planning/03-backend.md §7): the signed-in user deletes their own account.
// 1. caller from the JWT only (GET /auth/v1/user), never from the request body;
// 2. RPC prepare_account_deletion with the user's JWT (memberships -> name-only " (left)", profile cleared);
// 3. remove the user's avatar files (service key); 4. delete the auth user (service key).
// Every step can be retried: the RPC is idempotent and the JWT stays valid until step 4.
import { errorResponse, jsonResponse, requireMethod } from "../_shared/http.ts";

export type FetchFn = (input: string, init?: RequestInit) => Promise<Response>;
export type EnvGetter = (name: string) => string | undefined;

export interface Deps {
  fetch: FetchFn;
  env: EnvGetter;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const AVATAR_PAGE = 1000; // avatars are flat files <user_id>/<uuid>.jpg (0007); one page is plenty

class StepError extends Error {
  constructor(readonly code: string, readonly status = 502) {
    super(code);
  }
}

/** Discards a response body we do not read, so the connection is released. */
async function discard(res: Response): Promise<void> {
  await res.body?.cancel().catch(() => undefined);
}

export function createHandler(deps: Deps): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const wrongMethod = requireMethod(req, "POST");
    if (wrongMethod) return wrongMethod;

    const baseUrl = deps.env("SUPABASE_URL")?.replace(/\/+$/, "");
    const anonKey = deps.env("SUPABASE_ANON_KEY");
    const serviceKey = deps.env("SUPABASE_SERVICE_ROLE_KEY");
    if (!baseUrl || !anonKey || !serviceKey) {
      return errorResponse("MISCONFIGURED", 500);
    }

    const match = /^Bearer\s+(\S+)$/i.exec(
      req.headers.get("Authorization") ?? "",
    );
    if (!match) return errorResponse("NOT_AUTHENTICATED", 401);
    const jwt = match[1];

    const userHeaders = { apikey: anonKey, Authorization: `Bearer ${jwt}` };
    const serviceHeaders = {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
    };

    const call = async (
      code: string,
      path: string,
      init: RequestInit,
    ): Promise<Response> => {
      let res: Response;
      try {
        res = await deps.fetch(`${baseUrl}${path}`, init);
      } catch (_) {
        throw new StepError(code);
      }
      if (!res.ok) {
        await discard(res);
        console.error(`delete-account: ${code} (HTTP ${res.status})`);
        throw new StepError(code);
      }
      return res;
    };

    try {
      // 1. Who is calling: only the auth server's answer for this JWT counts.
      let userRes: Response;
      try {
        userRes = await deps.fetch(`${baseUrl}/auth/v1/user`, {
          method: "GET",
          headers: userHeaders,
        });
      } catch (_) {
        throw new StepError("USER_LOOKUP_FAILED");
      }
      if (!userRes.ok) {
        await discard(userRes);
        throw userRes.status < 500
          ? new StepError("NOT_AUTHENTICATED", 401)
          : new StepError("USER_LOOKUP_FAILED");
      }
      const user = await userRes.json().catch(() => null) as
        | { id?: unknown }
        | null;
      const userId = typeof user?.id === "string" && UUID_RE.test(user.id)
        ? user.id
        : null;
      if (!userId) throw new StepError("NOT_AUTHENTICATED", 401);

      // 2. Memberships -> name-only members, profile cleared (as the user, so auth.uid() is the caller).
      await discard(
        await call("PREPARE_FAILED", "/rest/v1/rpc/prepare_account_deletion", {
          method: "POST",
          headers: { ...userHeaders, "Content-Type": "application/json" },
          body: "{}",
        }),
      );

      // 3. Avatar files in the user's own folder.
      const listRes = await call(
        "AVATAR_LIST_FAILED",
        "/storage/v1/object/list/avatars",
        {
          method: "POST",
          headers: { ...serviceHeaders, "Content-Type": "application/json" },
          body: JSON.stringify({
            prefix: `${userId}/`,
            limit: AVATAR_PAGE,
            offset: 0,
          }),
        },
      );
      const listed = await listRes.json().catch(() => null);
      if (!Array.isArray(listed)) throw new StepError("AVATAR_LIST_FAILED");
      const prefixes = listed
        .filter((o) =>
          typeof o?.name === "string" && o.name !== "" && o.id !== null
        )
        .map((o) => `${userId}/${o.name}`);
      if (prefixes.length > 0) {
        await discard(
          await call("AVATAR_DELETE_FAILED", "/storage/v1/object/avatars", {
            method: "DELETE",
            headers: { ...serviceHeaders, "Content-Type": "application/json" },
            body: JSON.stringify({ prefixes }),
          }),
        );
      }

      // 4. The auth user; the profile row cascades, member rows keep user_id = null.
      await discard(
        await call("USER_DELETE_FAILED", `/auth/v1/admin/users/${userId}`, {
          method: "DELETE",
          headers: serviceHeaders,
        }),
      );

      return jsonResponse({ deleted: true });
    } catch (e) {
      if (e instanceof StepError) return errorResponse(e.code, e.status);
      throw e;
    }
  };
}
