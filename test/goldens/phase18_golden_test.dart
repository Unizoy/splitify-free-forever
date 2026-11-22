import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/data/local/app_database.dart' show LocalImportBatch;
import 'package:splitify/features/app_lock/application/app_lock_controller.dart';
import 'package:splitify/features/app_lock/domain/lock_policy.dart';
import 'package:splitify/features/app_lock/presentation/lock_screen.dart';
import 'package:splitify/features/app_lock/presentation/security_screen.dart';
import 'package:splitify/data/data_providers.dart' show groupUnsyncedProvider;
import 'package:splitify/features/groups/application/groups_providers.dart' show groupProvider;
import 'package:splitify/features/import_splitwise/application/import_controller.dart';
import 'package:splitify/features/import_splitwise/application/import_providers.dart';
import 'package:splitify/features/import_splitwise/domain/import_csv.dart';
import 'package:splitify/features/import_splitwise/domain/import_mapping.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_reconstruction.dart';
import 'package:splitify/features/import_splitwise/presentation/import_screen.dart';
import 'package:splitify/features/widget/application/home_widget_sync.dart';
import 'package:splitify/features/widget/domain/widget_data.dart';
import 'package:splitify/features/widget/presentation/widget_settings_screen.dart';

import '../features/expenses/expense_fixtures.dart' show expenseApp, gid, sampleGroup;
import 'golden_support.dart';

/// Import state the screen is driven from (the real domain builds it, like the controller does).
class _FixedImport extends ImportController {
  _FixedImport(this._state) : super(gid);

  final ImportState _state;

  @override
  ImportState build() => _state;
}

String _fixture(String name) => File('test/fixtures/splitwise/$name').readAsStringSync();

const _members = <MappingMember>[
  (id: 'm1', name: 'Mohit', isMe: true),
  (id: 'm2', name: 'Priya', isMe: false),
  (id: 'm3', name: 'Rohan Kumar', isMe: false),
];

ImportState _afterFile(String fixture, ImportStep step) {
  final parsed = parseImportCsv(_fixture(fixture));
  final mapping = suggestMapping(parsed.file.members, _members);
  final result = reconstructSplitwise(parsed.file, acceptTotalsMismatch: true);
  return ImportState(
    step: step,
    groupId: gid,
    fileName: fixture,
    parsed: parsed,
    members: _members,
    mapping: mapping,
    preview: (file: parsed.file, dropped: 0, result: result),
  );
}

ImportState _doneState() {
  final s = _afterFile('group_inr_usd.csv', ImportStep.done);
  return ImportState(
    step: ImportStep.done,
    groupId: gid,
    fileName: s.fileName,
    parsed: s.parsed,
    members: s.members,
    mapping: s.mapping,
    preview: s.preview,
    result: (batchId: 'b1', groupId: gid, expenses: 7, payments: 2),
  );
}

List<Override> _importOverrides(ImportState s, {bool unsynced = false}) => [
  importControllerProvider(gid).overrideWith(() => _FixedImport(s)),
  groupProvider.overrideWith((ref, id) => Stream.value(sampleGroup())),
  groupUnsyncedProvider.overrideWith((ref, id) => Stream.value(unsynced)),
  importBatchesProvider.overrideWith((ref, id) => Stream.value(const <LocalImportBatch>[])),
];

class _FixedLock extends AppLockController {
  _FixedLock(this._s);

  final AppLockState _s;

  @override
  AppLockState build() => _s;
}

class _Hide extends WidgetHideAmounts {
  @override
  bool build() => true;
}

Map<String, Object> _widgetData() => buildWidgetData(
  labels: widgetLabels(),
  signedIn: true,
  totals: const {'INR': 1245050, 'USD': 3200},
  first: 'INR',
  unsynced: false,
  lastSync: DateTime(2026, 11, 22, 10, 30),
  hideAmounts: true,
);

typedef _Case = (String, Widget Function(), List<Override> Function(), double);

List<_Case> _cases() => [
  (
    'import_file',
    () => const ImportScreen(groupId: gid),
    () => _importOverrides(const ImportState(step: ImportStep.file, groupId: gid)),
    915,
  ),
  (
    'import_file_error',
    () => const ImportScreen(groupId: gid),
    () => _importOverrides(
      const ImportState(
        step: ImportStep.file,
        groupId: gid,
        fileName: 'bad_header.csv',
        problem: (code: 'IMPORT_BAD_HEADER', row: 1, value: null),
      ),
    ),
    915,
  ),
  (
    'import_people',
    () => const ImportScreen(groupId: gid),
    () => _importOverrides(_afterFile('group_inr_usd.csv', ImportStep.people)),
    915,
  ),
  (
    'import_preview_ok',
    () => const ImportScreen(groupId: gid),
    () => _importOverrides(_afterFile('group_inr_usd.csv', ImportStep.preview)),
    1300,
  ),
  (
    'import_preview_mismatch',
    () => const ImportScreen(groupId: gid),
    () => _importOverrides(_afterFile('checksum_mismatch.csv', ImportStep.preview)),
    1300,
  ),
  (
    'import_done',
    () => const ImportScreen(groupId: gid),
    () => _importOverrides(_doneState(), unsynced: true),
    915,
  ),
  (
    'lock_screen',
    () => LockScreen(
      state: const AppLockState(enabled: true, timeout: LockTimeout.min5, locked: true),
      onUnlock: () {},
    ),
    () => const [],
    915,
  ),
  (
    'lock_screen_failed',
    () => LockScreen(
      state: const AppLockState(
        enabled: true,
        timeout: LockTimeout.min5,
        locked: true,
        notice: LockNotice.failed,
      ),
      onUnlock: () {},
    ),
    () => const [],
    915,
  ),
  (
    'security_off',
    () => const SecurityScreen(),
    () => [
      appLockProvider.overrideWith(
        () => _FixedLock(const AppLockState(enabled: false, timeout: LockTimeout.min5)),
      ),
    ],
    915,
  ),
  (
    'security_on',
    () => const SecurityScreen(),
    () => [
      appLockProvider.overrideWith(
        () => _FixedLock(const AppLockState(enabled: true, timeout: LockTimeout.min5)),
      ),
    ],
    915,
  ),
  (
    'widget_settings_hidden',
    () => const WidgetSettingsScreen(),
    () => [
      widgetHideAmountsProvider.overrideWith(_Hide.new),
      homeWidgetDataProvider.overrideWithValue(_widgetData()),
    ],
    915,
  ),
];

void main() {
  // TC-X1-03, TC-X2-01, TC-X3-01: the phase 18 screens in light and dark at text scale 1.0 and 2.0.
  for (final (name, screen, overrides, height) in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'phase 18 $name ${mode.name} $suffix',
          fileName: 'phase18_${name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () => expenseApp(
            screen(),
            overrides: overrides(),
            mode: mode,
            scale: scale,
            size: Size(goldenWidth, scale > 1 ? height * 1.8 : height),
          ),
        );
      }
    }
  }
}
