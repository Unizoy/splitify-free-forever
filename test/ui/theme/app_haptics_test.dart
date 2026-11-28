import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/theme/app_motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<Object?> platform;
  late List<String> custom;

  setUp(() {
    platform = [];
    custom = [];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') platform.add(call.arguments);
      return null;
    });
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(SystemChannels.platform, null)
      ..setMockMethodCallHandler(AppHaptics.channel, null);
  });

  Future<void> settle() => pumpEventQueue();

  group('AppHaptics', () {
    test('selection plays the platform selection click', () async {
      AppHaptics.selection();
      await settle();
      expect(platform, ['HapticFeedbackType.selectionClick']);
    });

    test('light plays the platform light impact', () async {
      AppHaptics.light();
      await settle();
      expect(platform, ['HapticFeedbackType.lightImpact']);
    });

    test('success and error use the splitify/haptics channel, not the fallback', () async {
      messenger.setMockMethodCallHandler(AppHaptics.channel, (call) async {
        custom.add(call.method);
        return null;
      });
      AppHaptics.success();
      AppHaptics.error();
      await settle();
      expect(custom, ['success', 'error']);
      expect(platform, isEmpty);
    });

    test('without the channel, success and error fall back to platform notifications', () async {
      AppHaptics.success();
      await settle();
      AppHaptics.error();
      await settle();
      expect(platform, [
        'HapticFeedbackType.successNotification',
        'HapticFeedbackType.errorNotification',
      ]);
    });

    test('a PlatformException from the channel also falls back', () async {
      messenger.setMockMethodCallHandler(AppHaptics.channel, (call) async {
        throw PlatformException(code: 'nope');
      });
      AppHaptics.success();
      await settle();
      AppHaptics.error();
      await settle();
      expect(platform, [
        'HapticFeedbackType.successNotification',
        'HapticFeedbackType.errorNotification',
      ]);
    });
  });
}
