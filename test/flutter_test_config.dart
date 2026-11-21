import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/painters/cover_cache.dart';

/// Runs once per test file. Golden tests (alchemist) use two flavours:
/// - CI goldens (obscured text, so they match on Linux CI and Windows alike);
/// - platform goldens with real fonts, Windows only and opt-in for local visual
///   review: set PLATFORM_GOLDENS=1 (they are git-ignored, S-007).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // The cover cache fills in the background; start every test empty so goldens are stable.
  setUp(() => CoverCache.instance.clear());
  await AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(
        enabled:
            HostPlatform.current().isWindows && Platform.environment['PLATFORM_GOLDENS'] == '1',
        platforms: {HostPlatform.windows},
      ),
      ciGoldensConfig: const CiGoldensConfig(),
    ),
    run: testMain,
  );
}
