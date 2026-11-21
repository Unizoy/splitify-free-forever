import 'dart:async';

/// Runs once per test file. Phase 02 loads the bundled fonts here so golden
/// tests look the same on every machine.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
