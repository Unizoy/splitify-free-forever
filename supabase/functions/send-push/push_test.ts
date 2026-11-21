// TC-19-02 [edge]: send-push is idempotent and cleans up dead tokens. Fake DB + fake FCM, no network.
import { assertEquals } from "jsr:@std/assert@1";
import type { FcmClient, FcmMessage, FcmSendResult } from "../_shared/fcm.ts";
import {
  buildFcmMessage,
  type DeviceToken,
  handleSendPush,
  type NotificationRow,
  type NotificationSettings,
  type PushDb,
  type PushStatus,
  sendPush,
} from "./push.ts";

const ID = "6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b";
const USER = "0b8e7d6c-5b4a-4398-8765-43210fedcba9";
const GROUP = "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d";

function notification(over: Partial<NotificationRow> = {}): NotificationRow {
  return {
    id: ID,
    user_id: USER,
    group_id: GROUP,
    kind: "expenses",
    title: "Goa trip",
    body: "Rahul added “Dinner” · ₹1,200",
    data: { route: `/groups/${GROUP}/expenses/e1`, amount: 120000 },
    push_status: "pending",
    ...over,
  };
}

class FakeDb implements PushDb {
  rows = new Map<string, NotificationRow>();
  settings = new Map<string, NotificationSettings>();
  tokens: (DeviceToken & { user_id: string })[] = [];
  deleted: string[] = [];
  constructor(n: NotificationRow | null = notification()) {
    if (n) this.rows.set(n.id, n);
  }
  getNotification(id: string) {
    const n = this.rows.get(id);
    return Promise.resolve(n ? { ...n } : null);
  }
  getSettings(userId: string) {
    return Promise.resolve(this.settings.get(userId) ?? null);
  }
  getDeviceTokens(userId: string) {
    return Promise.resolve(
      this.tokens.filter((t) => t.user_id === userId).map(({ id, token }) => ({
        id,
        token,
      })),
    );
  }
  deleteDeviceTokens(ids: string[]) {
    this.deleted.push(...ids);
    this.tokens = this.tokens.filter((t) => !ids.includes(t.id));
    return Promise.resolve();
  }
  setPushStatus(id: string, to: PushStatus, from: PushStatus) {
    const n = this.rows.get(id);
    if (!n || n.push_status !== from) return Promise.resolve(false);
    n.push_status = to;
    return Promise.resolve(true);
  }
  status() {
    return this.rows.get(ID)?.push_status;
  }
}

/** Fake FCM: answers per device token; records every message. */
function fakeFcm(
  answers: Record<string, FcmSendResult> = {},
): FcmClient & { sent: FcmMessage[] } {
  const sent: FcmMessage[] = [];
  return {
    projectId: "p",
    sent,
    send(message) {
      sent.push(message);
      return Promise.resolve(answers[message.token] ?? { ok: true, name: "m" });
    },
  };
}

const unregistered: FcmSendResult = {
  ok: false,
  status: 404,
  code: "UNREGISTERED",
  invalidToken: true,
};
const unavailable: FcmSendResult = {
  ok: false,
  status: 503,
  code: "UNAVAILABLE",
  invalidToken: false,
};

function withTokens(db: FakeDb, ...tokens: string[]) {
  tokens.forEach((token, i) =>
    db.tokens.push({ id: `t${i + 1}`, token, user_id: USER })
  );
  return db;
}

Deno.test("buildFcmMessage maps the notification to an FCM v1 message with string data", () => {
  assertEquals(buildFcmMessage(notification(), "dev-a"), {
    token: "dev-a",
    notification: { title: "Goa trip", body: "Rahul added “Dinner” · ₹1,200" },
    data: {
      route: `/groups/${GROUP}/expenses/e1`,
      amount: "120000",
      notification_id: ID,
      kind: "expenses",
      group_id: GROUP,
    },
    android: { priority: "HIGH", notification: { channel_id: "expenses" } },
  });
  const bare = buildFcmMessage(
    notification({ group_id: null, data: null, kind: "reminders" }),
    "d",
  );
  assertEquals(bare.data, { notification_id: ID, kind: "reminders" });
  assertEquals(bare.android.notification.channel_id, "reminders");
});

Deno.test("TC-19-02 a pending notification is sent once; a second call is a duplicate", async () => {
  const db = withTokens(new FakeDb(), "dev-a", "dev-b");
  const fcm = fakeFcm();
  assertEquals(await sendPush(ID, { db, fcm }), {
    outcome: "sent",
    delivered: 2,
    failed: 0,
    removed_tokens: 0,
    errors: [],
  });
  assertEquals(db.status(), "sent");
  assertEquals(fcm.sent.map((m) => m.token), ["dev-a", "dev-b"]);

  assertEquals(await sendPush(ID, { db, fcm }), {
    outcome: "duplicate",
    push_status: "sent",
  });
  assertEquals(fcm.sent.length, 2);
});

Deno.test("TC-19-02 UNREGISTERED tokens are deleted, live ones still get the push", async () => {
  const db = withTokens(new FakeDb(), "dead", "live");
  const result = await sendPush(ID, {
    db,
    fcm: fakeFcm({ dead: unregistered }),
  });
  assertEquals(result, {
    outcome: "sent",
    delivered: 1,
    failed: 1,
    removed_tokens: 1,
    errors: ["UNREGISTERED"],
  });
  assertEquals(db.deleted, ["t1"]);
  assertEquals(db.tokens.map((t) => t.token), ["live"]);
});

Deno.test("nothing delivered marks the push failed; transient errors keep the token", async () => {
  const db = withTokens(new FakeDb(), "a", "b");
  const result = await sendPush(ID, {
    db,
    fcm: fakeFcm({ a: unavailable, b: unregistered }),
  });
  assertEquals(result, {
    outcome: "failed",
    delivered: 0,
    failed: 2,
    removed_tokens: 1,
    errors: ["UNAVAILABLE", "UNREGISTERED"],
  });
  assertEquals(db.status(), "failed");
  assertEquals(db.tokens.map((t) => t.token), ["a"]);
});

Deno.test("D-020 dummy mode: no FCM secret → skipped, nothing sent", async () => {
  const db = withTokens(new FakeDb(), "a");
  assertEquals(await sendPush(ID, { db, fcm: null }), {
    outcome: "skipped",
    reason: "NO_FCM_CONFIG",
  });
  assertEquals(db.status(), "skipped");
});

Deno.test("an unreadable FCM secret marks the push failed", async () => {
  const db = withTokens(new FakeDb(), "a");
  const result = await sendPush(ID, {
    db,
    fcm: null,
    fcmConfigError: "FCM service account is not valid JSON",
  });
  assertEquals(result.outcome, "failed");
  assertEquals(db.status(), "failed");
});

Deno.test("per-user settings: push off for the kind or a muted group → skipped", async () => {
  const off = withTokens(new FakeDb(), "a");
  off.settings.set(USER, {
    kinds: { expenses: { push: false, inapp: true } },
    muted_group_ids: [],
  });
  const fcm = fakeFcm();
  assertEquals(await sendPush(ID, { db: off, fcm }), {
    outcome: "skipped",
    reason: "PUSH_DISABLED",
  });

  const muted = withTokens(new FakeDb(), "a");
  muted.settings.set(USER, { kinds: null, muted_group_ids: [GROUP] });
  assertEquals(await sendPush(ID, { db: muted, fcm }), {
    outcome: "skipped",
    reason: "GROUP_MUTED",
  });

  const otherKindOff = withTokens(new FakeDb(), "a");
  otherKindOff.settings.set(USER, {
    kinds: { payments: { push: false } },
    muted_group_ids: null,
  });
  assertEquals((await sendPush(ID, { db: otherKindOff, fcm })).outcome, "sent");
  assertEquals(fcm.sent.length, 1);
});

Deno.test("no devices → skipped; unknown or already handled ids send nothing", async () => {
  const fcm = fakeFcm();
  const db = new FakeDb();
  assertEquals(await sendPush(ID, { db, fcm }), {
    outcome: "skipped",
    reason: "NO_DEVICES",
  });
  assertEquals(await sendPush(ID, { db: new FakeDb(null), fcm }), {
    outcome: "not_found",
  });
  for (const s of ["sent", "skipped", "failed"] as const) {
    const handled = withTokens(
      new FakeDb(notification({ push_status: s })),
      "a",
    );
    assertEquals(await sendPush(ID, { db: handled, fcm }), {
      outcome: "duplicate",
      push_status: s,
    });
  }
  assertEquals(fcm.sent.length, 0);
});

Deno.test("a concurrent call that loses the claim sends nothing", async () => {
  const db = withTokens(new FakeDb(), "a");
  // The other call claims between our read and our claim.
  const realGet = db.getNotification.bind(db);
  db.getNotification = async (id) => {
    const n = await realGet(id);
    db.rows.get(ID)!.push_status = "sent";
    return n;
  };
  const fcm = fakeFcm();
  assertEquals(await sendPush(ID, { db, fcm }), {
    outcome: "duplicate",
    push_status: "sent",
  });
  assertEquals(fcm.sent.length, 0);
});

Deno.test("handleSendPush validates method and body, maps outcomes to HTTP", async () => {
  const post = (body: string) =>
    new Request("http://x", { method: "POST", body });
  const deps = { db: withTokens(new FakeDb(), "a"), fcm: fakeFcm() };

  const get = await handleSendPush(new Request("http://x"), deps);
  assertEquals(get.status, 405);
  await get.body?.cancel();
  for (const body of ["nope", "{}", '{"notification_id":"1; drop"}']) {
    const res = await handleSendPush(post(body), deps);
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "INVALID_BODY");
  }
  const missing = await handleSendPush(
    post(JSON.stringify({ notification_id: USER })),
    deps,
  );
  assertEquals(missing.status, 404);
  await missing.body?.cancel();

  const ok = await handleSendPush(
    post(JSON.stringify({ notification_id: ID })),
    deps,
  );
  assertEquals(ok.status, 200);
  assertEquals((await ok.json()).outcome, "sent");

  const broken = new FakeDb();
  broken.getNotification = () => Promise.reject(new Error("db down"));
  const err = await handleSendPush(
    post(JSON.stringify({ notification_id: ID })),
    { db: broken, fcm: null },
  );
  assertEquals(err.status, 500);
  assertEquals(await err.json(), { error: "INTERNAL" });
});
