// The real app (same bootstrap as lib/main.dart) with the S-214 DNS pin, for hands-on device checks of the real
// services (Google sign-in, email codes, push) on this PC, whose ISP blocks `*.supabase.co`:
//   flutter build apk --release --target-platform android-x64 -t integration_test/support/pinned_main.dart \
//     --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=<ip resolved on the PC>
// Release builds are signed with the debug key when no secrets/release-key.properties or secrets/key.properties
// exists (android/app/build.gradle.kts, S-201), so the debug SHA-1 registered for Google sign-in matches; with the
// release key, its SHA-1 must be registered too. Never shipped: the store build uses lib/main.dart.
import 'package:flutter/widgets.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/core/config/env.dart';

import 'net_pin.dart';

Future<void> main() async {
  pinHost(Uri.parse(Env.load().supabaseUrl).host);
  runApp(await bootstrap());
}
