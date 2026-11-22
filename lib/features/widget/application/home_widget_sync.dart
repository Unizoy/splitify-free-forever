import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:logging/logging.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/widget/domain/widget_data.dart';
import 'package:splitify/l10n/app_localizations.dart';

final _log = Logger('widget');

/// Native widget providers (class names in `AndroidManifest.xml`).
const widgetReceivers = ['BalanceWidgetSmall', 'BalanceWidgetWide'];

/// Writes the widget's values and asks Android to redraw (a seam over `home_widget` for tests).
abstract interface class HomeWidgetBridge {
  Future<void> save(Map<String, Object> data);
}

class PluginHomeWidgetBridge implements HomeWidgetBridge {
  const PluginHomeWidgetBridge();

  @override
  Future<void> save(Map<String, Object> data) async {
    try {
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<Object>(e.key, e.value);
      }
      for (final name in widgetReceivers) {
        await HomeWidget.updateWidget(androidName: name);
      }
    } on PlatformException catch (e) {
      _log.fine('widget update skipped: ${e.code}');
    } on MissingPluginException {
      // Tests and platforms without widgets.
    }
  }
}

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>(
  (ref) => const PluginHomeWidgetBridge(),
);

/// "Hide amounts" (X3 privacy option), kept on this phone.
final widgetHideAmountsProvider = NotifierProvider<WidgetHideAmounts, bool>(WidgetHideAmounts.new);

class WidgetHideAmounts extends Notifier<bool> {
  static const key = 'widget.hide_amounts';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(key) ?? false;

  Future<void> set({required bool hide}) async {
    await ref.read(sharedPreferencesProvider).setBool(key, hide);
    state = hide;
  }
}

/// Labels from the ARB file (the app is English only, D-009; no BuildContext here).
WidgetLabels widgetLabels([AppLocalizations? l10n]) {
  final l = l10n ?? lookupAppLocalizations(const Locale('en'));
  return (
    brand: l.widgetBrand,
    owed: l.youAreOwed,
    owe: l.youOwe,
    settled: l.allSettled,
    mixed: l.statusOwedAndOwe,
    hidden: l.widgetHidden,
    updatedTemplate: l.widgetUpdated('%s'),
    updatedNow: l.widgetUpdatedNow,
    notSynced: l.widgetNotSynced,
    signedOut: l.widgetSignedOut,
  );
}

/// The widget's values right now (null while balances are still loading).
final homeWidgetDataProvider = Provider.autoDispose<Map<String, Object>?>((ref) {
  final signedIn = ref.watch(currentUserIdProvider) != null;
  final hide = ref.watch(widgetHideAmountsProvider);
  final labels = widgetLabels();
  if (!signedIn) {
    return buildWidgetData(
      labels: labels,
      signedIn: false,
      totals: const {},
      first: 'INR',
      unsynced: false,
      lastSync: null,
      hideAmounts: hide,
    );
  }
  final mine = ref.watch(myBalancesProvider);
  if (!mine.hasValue) return null;
  final b = mine.requireValue;
  return buildWidgetData(
    labels: labels,
    signedIn: true,
    totals: b.totals,
    first: ref.watch(profileProvider).value?.defaultCurrency ?? 'INR',
    unsynced: b.unsynced || (ref.watch(anyUnsyncedProvider).value ?? false),
    lastSync: ref.watch(syncStatusProvider).value?.lastSync,
    hideAmounts: hide,
  );
});

/// Keeps the home-screen widget in step: after every local write or sync the balances provider
/// changes and the new values are written (debounced, only when they changed). Watched by the app.
final homeWidgetSyncProvider = Provider<void>((ref) {
  Map<String, Object>? last;
  Timer? timer;
  ref
    ..onDispose(() => timer?.cancel())
    ..listen<Map<String, Object>?>(homeWidgetDataProvider, (_, data) {
      if (data == null || _same(data, last)) return;
      timer?.cancel();
      timer = Timer(const Duration(milliseconds: 400), () {
        last = data;
        unawaited(ref.read(homeWidgetBridgeProvider).save(data));
      });
    }, fireImmediately: true);
});

bool _same(Map<String, Object> a, Map<String, Object>? b) {
  if (b == null || a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

/// Background sync (WorkManager isolate, phase 15) has no app widget tree watching
/// [homeWidgetSyncProvider]: after its sync it calls this once to write the widget's values.
Future<void> refreshHomeWidget(ProviderContainer container) async {
  final sub = container.listen(homeWidgetDataProvider, (_, _) {});
  try {
    // Balances come from Drift streams: give them a moment to load.
    for (var i = 0; i < 50 && container.read(homeWidgetDataProvider) == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final data = container.read(homeWidgetDataProvider);
    if (data != null) await container.read(homeWidgetBridgeProvider).save(data);
  } finally {
    sub.close();
  }
}
