// send-push logic (03-backend.md §5 §7, phase 13 T3, TC-19-02). Pure apart from the injected DB and FCM client.
//
// Idempotent: only a notification with push_status 'pending' is handled, and the move away from 'pending' is a
// conditional update, so a second call (or a stranger replaying an id) can never send again. Order:
//   load → not pending: duplicate → dummy mode / push off for kind / muted group / no devices: 'skipped'
//   → claim pending→'sent' → send to every device → delete dead tokens → nothing delivered: 'sent'→'failed'.
// A crash after the claim leaves 'sent' without a push: at most once is the right failure for a reminder app,
// and the in-app bell row exists anyway.

import { errorResponse, jsonResponse, requireMethod } from "../_shared/http.ts";
import type { FcmClient, FcmMessage } from "../_shared/fcm.ts";

export type PushStatus = "pending" | "sent" | "skipped" | "failed";

/** The `notifications` columns send-push reads. `kind` is the channel kind (expenses, payments, ...). */
export interface NotificationRow {
  id: string;
  user_id: string;
  group_id: string | null;
  kind: string;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  push_status: PushStatus;
}

/** `notification_settings`: `kinds = {kind: {push, inapp}}`; a missing row or entry means on. */
export interface NotificationSettings {
  kinds: Record<string, { push?: boolean; inapp?: boolean }> | null;
  muted_group_ids: string[] | null;
}

export interface DeviceToken {
  id: string;
  token: string;
}

/** The only database access send-push needs; index.ts implements it with supabase-js (secret key). */
export interface PushDb {
  getNotification(id: string): Promise<NotificationRow | null>;
  getSettings(userId: string): Promise<NotificationSettings | null>;
  getDeviceTokens(userId: string): Promise<DeviceToken[]>;
  deleteDeviceTokens(ids: string[]): Promise<void>;
  /** `update notifications set push_status = to where id = $1 and push_status = from`; true if a row changed. */
  setPushStatus(id: string, to: PushStatus, from: PushStatus): Promise<boolean>;
}

export interface SendPushDeps {
  db: PushDb;
  /** null = dummy mode (D-020): `FCM_SERVICE_ACCOUNT_JSON` is not set, every push is 'skipped'. */
  fcm: FcmClient | null;
  /** Set when the secret exists but can't be parsed; pushes are marked 'failed'. Never contains the key. */
  fcmConfigError?: string;
}

export type SkipReason =
  | "NO_FCM_CONFIG"
  | "PUSH_DISABLED"
  | "GROUP_MUTED"
  | "NO_DEVICES";

export type SendPushResult =
  | { outcome: "not_found" }
  | { outcome: "duplicate"; push_status: PushStatus }
  | { outcome: "skipped"; reason: SkipReason }
  | {
    outcome: "sent" | "failed";
    delivered: number;
    failed: number;
    removed_tokens: number;
    errors: string[];
  };

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** FCM `data` must be string → string: strings pass through, everything else is JSON-encoded. */
export function toFcmData(n: NotificationRow): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(n.data ?? {})) {
    if (v === null || v === undefined) continue;
    out[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  out.notification_id = n.id;
  out.kind = n.kind;
  if (n.group_id) out.group_id = n.group_id;
  return out;
}

/** The FCM v1 message for one device; the Android channel id is the notification kind (phase 13 T1). */
export function buildFcmMessage(n: NotificationRow, token: string): FcmMessage {
  return {
    token,
    notification: { title: n.title, body: n.body },
    data: toFcmData(n),
    android: { priority: "HIGH", notification: { channel_id: n.kind } },
  };
}

/** Per-user settings check: push for this kind on, group not muted (muted = in-app only, 08 #19). */
export function pushBlockedBy(
  n: NotificationRow,
  settings: NotificationSettings | null,
): "PUSH_DISABLED" | "GROUP_MUTED" | null {
  if (settings?.kinds?.[n.kind]?.push === false) return "PUSH_DISABLED";
  if (n.group_id && settings?.muted_group_ids?.includes(n.group_id)) {
    return "GROUP_MUTED";
  }
  return null;
}

async function skip(
  db: PushDb,
  n: NotificationRow,
  reason: SkipReason,
): Promise<SendPushResult> {
  if (!(await db.setPushStatus(n.id, "skipped", "pending"))) {
    return { outcome: "duplicate", push_status: "skipped" };
  }
  return { outcome: "skipped", reason };
}

/** One notification → FCM. Safe to call any number of times for the same id. */
export async function sendPush(
  notificationId: string,
  deps: SendPushDeps,
): Promise<SendPushResult> {
  const { db } = deps;
  const n = await db.getNotification(notificationId);
  if (!n) return { outcome: "not_found" };
  if (n.push_status !== "pending") {
    return { outcome: "duplicate", push_status: n.push_status };
  }
  if (deps.fcmConfigError) {
    if (!(await db.setPushStatus(n.id, "failed", "pending"))) {
      return { outcome: "duplicate", push_status: "failed" };
    }
    return {
      outcome: "failed",
      delivered: 0,
      failed: 0,
      removed_tokens: 0,
      errors: [deps.fcmConfigError],
    };
  }
  if (!deps.fcm) return skip(db, n, "NO_FCM_CONFIG");

  const blocked = pushBlockedBy(n, await db.getSettings(n.user_id));
  if (blocked) return skip(db, n, blocked);

  const tokens = await db.getDeviceTokens(n.user_id);
  if (tokens.length === 0) return skip(db, n, "NO_DEVICES");

  if (!(await db.setPushStatus(n.id, "sent", "pending"))) {
    return { outcome: "duplicate", push_status: "sent" };
  }
  const fcm = deps.fcm;
  const results = await Promise.all(
    tokens.map((t) => fcm.send(buildFcmMessage(n, t.token))),
  );
  const dead: string[] = [];
  const errors = new Set<string>();
  let delivered = 0;
  results.forEach((r, i) => {
    if (r.ok) {
      delivered++;
      return;
    }
    errors.add(r.code);
    if (r.invalidToken) dead.push(tokens[i].id);
  });
  if (dead.length) await db.deleteDeviceTokens(dead);
  let outcome: "sent" | "failed" = "sent";
  if (delivered === 0) {
    await db.setPushStatus(n.id, "failed", "sent");
    outcome = "failed";
  }
  return {
    outcome,
    delivered,
    failed: results.length - delivered,
    removed_tokens: dead.length,
    errors: [...errors].sort(),
  };
}

/** HTTP wrapper: `POST {"notification_id": "<uuid>"}` from the DB trigger via pg_net (verify_jwt false). */
export async function handleSendPush(
  req: Request,
  deps: SendPushDeps,
): Promise<Response> {
  const notAllowed = requireMethod(req, "POST");
  if (notAllowed) return notAllowed;
  let id: unknown;
  try {
    id = ((await req.json()) as { notification_id?: unknown })?.notification_id;
  } catch {
    return errorResponse("INVALID_BODY", 400, "body must be JSON");
  }
  if (typeof id !== "string" || !UUID_RE.test(id)) {
    return errorResponse("INVALID_BODY", 400, "notification_id must be a uuid");
  }
  try {
    const result = await sendPush(id, deps);
    console.log("send-push", id, JSON.stringify(result));
    if (result.outcome === "not_found") {
      return errorResponse("NOT_FOUND", 404);
    }
    return jsonResponse(result);
  } catch (e) {
    console.error("send-push failed", id, (e as Error).message);
    return errorResponse("INTERNAL", 500);
  }
}
