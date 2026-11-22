import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/features/widget/application/home_widget_sync.dart';

class _FakeBridge implements HomeWidgetBridge {
  final saved = <Map<String, Object>>[];

  @override
  Future<void> save(Map<String, Object> data) async => saved.add(data);
}

class _Data extends Notifier<Map<String, Object>?> {
  @override
  Map<String, Object>? build() => null;

  Map<String, Object>? get value => state;

  set value(Map<String, Object>? v) => state = v;
}

final _data = NotifierProvider<_Data, Map<String, Object>?>(_Data.new);

void main() {
  test('WidgetHideAmounts persists to preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    expect(c.read(widgetHideAmountsProvider), isFalse);
    await c.read(widgetHideAmountsProvider.notifier).set(hide: true);
    expect(c.read(widgetHideAmountsProvider), isTrue);
    expect(prefs.getBool(WidgetHideAmounts.key), isTrue);

    final c2 = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c2.dispose);
    expect(c2.read(widgetHideAmountsProvider), isTrue);
  });

  group('homeWidgetSyncProvider', () {
    late _FakeBridge bridge;
    late ProviderContainer c;

    setUp(() {
      bridge = _FakeBridge();
      c = ProviderContainer(
        overrides: [
          homeWidgetBridgeProvider.overrideWithValue(bridge),
          homeWidgetDataProvider.overrideWith((ref) => ref.watch(_data)),
        ],
      );
      addTearDown(c.dispose);
    });

    testWidgets('writes after the debounce, not again for unchanged data', (tester) async {
      c.read(_data.notifier).value = {'line1': '₹10'};
      c.listen(homeWidgetSyncProvider, (_, _) {});
      await tester.pump(const Duration(milliseconds: 399));
      expect(bridge.saved, isEmpty);
      await tester.pump(const Duration(milliseconds: 2));
      expect(bridge.saved, [
        {'line1': '₹10'},
      ]);

      // Same content in a new map: nothing more is written.
      c.read(_data.notifier).value = {'line1': '₹10'};
      await tester.pump(const Duration(seconds: 2));
      expect(bridge.saved, hasLength(1));

      // Changed content writes again.
      c.read(_data.notifier).value = {'line1': '₹20'};
      await tester.pump(const Duration(milliseconds: 500));
      expect(bridge.saved, hasLength(2));
      expect(bridge.saved.last['line1'], '₹20');
    });

    testWidgets('rapid changes are debounced into the last value', (tester) async {
      c.listen(homeWidgetSyncProvider, (_, _) {});
      c.read(_data.notifier).value = {'v': 1};
      await tester.pump(const Duration(milliseconds: 200));
      c.read(_data.notifier).value = {'v': 2};
      await tester.pump(const Duration(milliseconds: 500));
      expect(bridge.saved, [
        {'v': 2},
      ]);
    });

    testWidgets('null (still loading) writes nothing', (tester) async {
      c.listen(homeWidgetSyncProvider, (_, _) {});
      await tester.pump(const Duration(seconds: 1));
      expect(bridge.saved, isEmpty);
    });
  });

  test('refreshHomeWidget (background sync) writes the current values once', () async {
    final bridge = _FakeBridge();
    final c = ProviderContainer(
      overrides: [
        homeWidgetBridgeProvider.overrideWithValue(bridge),
        homeWidgetDataProvider.overrideWith((ref) => const {'line1': '₹500'}),
      ],
    );
    addTearDown(c.dispose);
    await refreshHomeWidget(c);
    expect(bridge.saved, [
      {'line1': '₹500'},
    ]);
  });

  test('widgetLabels returns the ARB texts', () {
    final l = widgetLabels();
    expect(l.brand, isNotEmpty);
    expect(l.owed, isNotEmpty);
    expect(l.owe, isNotEmpty);
    expect(l.settled, isNotEmpty);
    expect(l.mixed, isNotEmpty);
    expect(l.hidden, isNotEmpty);
    expect(l.notSynced, isNotEmpty);
    expect(l.signedOut, isNotEmpty);
    expect(l.updatedTemplate, contains('%s'));
  });
}
