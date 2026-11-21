import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'net_pin.dart';

/// Build settings compiled in by `--dart-define-from-file=secrets/env.dev.json`; fails fast without them.
/// Also applies the optional `PIN_HOST_IP` DNS workaround (S-214) before any client is created.
Env devEnv() {
  final env = Env.load();
  if (!isConfiguredValue(env.supabaseUrl) || env.e2ePassword.isEmpty) {
    fail('Run with --dart-define-from-file=secrets/env.dev.json (dev project + E2E_PASSWORD).');
  }
  pinHost(Uri.parse(env.supabaseUrl).host);
  return env;
}

/// Test user email (`e2e-a` → `e2e-a@splitify.test`).
String e2eEmail(String user) => '$user@splitify.test';

/// Pumps real-time frames until [done] is true (network work runs on the real clock here).
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 30),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (done()) return;
  }
  fail('Timed out: ${reason ?? 'condition'}');
}

/// A second person driven through the Supabase API (multi-user harness, 09 testing strategy): its own
/// client and session, nothing persisted on the phone.
class HarnessUser {
  HarnessUser._(this.client);

  final SupabaseClient client;

  /// Signs [user] in, creating the account on first use (email confirmation is off on dev).
  static Future<HarnessUser> signIn(Env env, String user) async {
    final client = SupabaseClient(
      env.supabaseUrl,
      env.supabasePublishableKey,
      // Implicit flow: PKCE would need async storage, and nothing here is persisted.
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    final email = e2eEmail(user);
    try {
      await client.auth.signInWithPassword(email: email, password: env.e2ePassword);
    } on AuthException {
      await client.auth.signUp(email: email, password: env.e2ePassword);
    }
    return HarnessUser._(client);
  }

  String get id => client.auth.currentUser!.id;

  Future<Map<String, Object?>> rpc(String fn, [Map<String, Object?>? params]) async =>
      ((await client.rpc<Object?>(fn, params: params))! as Map).cast<String, Object?>();

  Future<void> dispose() async {
    await client.auth.signOut(scope: SignOutScope.local);
    await client.dispose();
  }
}
