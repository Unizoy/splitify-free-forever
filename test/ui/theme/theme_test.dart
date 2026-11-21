import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/theme/theme.dart';

void main() {
  // TC-B3-03: tokens interpolate cleanly for the animated theme switch.
  test('AppColors lerp at 0 and 1 returns the endpoints', () {
    final start = AppColors.light.lerp(AppColors.dark, 0);
    final end = AppColors.light.lerp(AppColors.dark, 1);
    expect(start.bg, AppColors.light.bg);
    expect(start.textPrimary, AppColors.light.textPrimary);
    expect(end.bg, AppColors.dark.bg);
    expect(end.textPrimary, AppColors.dark.textPrimary);
    expect(end.contrastPairs.length, AppColors.dark.contrastPairs.length);
  });

  test('AppColors lerp with another type returns itself', () {
    expect(AppColors.light.lerp(null, 0.5), same(AppColors.light));
  });

  test('AppText lerp at 0 and 1 returns the endpoints', () {
    final a = AppText.withColor(AppColors.light.textPrimary);
    final b = AppText.withColor(AppColors.dark.textPrimary);
    final start = a.lerp(b, 0);
    final end = a.lerp(b, 1);
    expect(start.body, a.body);
    expect(start.heroDisplay, a.heroDisplay);
    expect(end.body, b.body);
    expect(end.amount, b.amount);
    expect(a.lerp(null, 0.5), same(a));
  });

  test('AppTheme light and dark carry brightness and token extensions', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    for (final t in [light, dark]) {
      expect(t.extension<AppColors>(), isNotNull);
      expect(t.extension<AppText>(), isNotNull);
    }
    expect(light.extension<AppColors>()!.bg, AppColors.light.bg);
    expect(dark.extension<AppColors>()!.bg, AppColors.dark.bg);
  });

  testWidgets('context extensions resolve the active theme', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(ctx.isDark, isTrue);
    expect(ctx.colors.bg, AppColors.dark.bg);
    expect(ctx.motion.reduced, isFalse);
  });

  test('SpringCurve starts at 0 and settles at 1', () {
    const curve = SpringCurve();
    expect(curve.transform(0), 0);
    expect(curve.transform(1), closeTo(1, 0.02));
  });

  testWidgets('AppMotion durations are zero when animations are disabled', (tester) async {
    late AppMotion reduced;
    late AppMotion normal;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (c) {
            reduced = AppMotion.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          normal = AppMotion.of(c);
          return const SizedBox();
        },
      ),
    );
    expect(reduced.fast, Duration.zero);
    expect(reduced.base, Duration.zero);
    expect(reduced.slow, Duration.zero);
    expect(reduced.showcase, Duration.zero);
    expect(normal.fast, const Duration(milliseconds: 150));
    expect(normal.showcase, const Duration(milliseconds: 800));
  });
}
