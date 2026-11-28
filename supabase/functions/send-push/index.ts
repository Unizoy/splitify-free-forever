// Edge Function `send-push` (verify_jwt = false). Called by the `private.queue_push()` trigger via pg_net with
// `{"notification_id": "<uuid>"}` (03-backend.md §5). Wiring only: logic and tests live in push.ts / push_test.ts.

import { createClient } from "npm:@supabase/supabase-js@2";
import { adminCredentials } from "../_shared/admin_client.ts";
import {
  createFcmClient,
  type FcmClient,
  parseServiceAccount,
} from "../_shared/fcm.ts";
import { handleSendPush, type NotificationRow, type PushDb } from "./push.ts";

function supabasePushDb(): PushDb {
  const { url, key } = adminCredentials((name) => Deno.env.get(name));
  const sb = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return {
    async getNotification(id) {
      const { data, error } = await sb.from("notifications")
        .select(
          "id,user_id,group_id,kind,title,body,data,push_status,push_title,push_body",
        )
        .eq("id", id).maybeSingle();
      if (error) throw new Error(`notifications read: ${error.message}`);
      return data as NotificationRow | null;
    },
    async getSettings(userId) {
      const { data, error } = await sb.from("notification_settings")
        .select("kinds,muted_group_ids").eq("user_id", userId).maybeSingle();
      if (error) {
        throw new Error(`notification_settings read: ${error.message}`);
      }
      return data;
    },
    async getDeviceTokens(userId) {
      const { data, error } = await sb.from("device_tokens").select("id,token")
        .eq("user_id", userId);
      if (error) throw new Error(`device_tokens read: ${error.message}`);
      return data ?? [];
    },
    async deleteDeviceTokens(ids) {
      const { error } = await sb.from("device_tokens").delete().in("id", ids);
      if (error) throw new Error(`device_tokens delete: ${error.message}`);
    },
    async setPushStatus(id, to, from) {
      const { data, error } = await sb.from("notifications")
        .update({ push_status: to }).eq("id", id).eq("push_status", from)
        .select("id");
      if (error) throw new Error(`notifications update: ${error.message}`);
      return (data ?? []).length > 0;
    },
  };
}

// One FCM client per warm isolate, so the OAuth token cache survives between calls.
let fcmState: { fcm: FcmClient | null; fcmConfigError?: string } | null = null;

function fcmFromEnv(): { fcm: FcmClient | null; fcmConfigError?: string } {
  if (fcmState) return fcmState;
  const json = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!json) {
    fcmState = { fcm: null }; // D-020 dummy mode: pushes are 'skipped'.
  } else {
    try {
      fcmState = {
        fcm: createFcmClient(parseServiceAccount(json), {
          fetch,
          now: () => Date.now(),
        }),
      };
    } catch (e) {
      fcmState = { fcm: null, fcmConfigError: (e as Error).message };
    }
  }
  return fcmState;
}

Deno.serve((req) =>
  handleSendPush(req, { db: supabasePushDb(), ...fcmFromEnv() })
);
