import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/ui/theme/app_colors.dart';
import 'package:splitify/ui/theme/app_radii.dart';
import 'package:splitify/ui/theme/app_text.dart';

/// Builds the light and dark [ThemeData] from the tokens. Dynamic colour is off.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final text = AppText.withColor(c.textPrimary);
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: isDark ? c.bg : c.onPrimaryFill,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.money,
      onSecondary: c.onMoney,
      tertiary: c.owedText,
      onTertiary: c.bg,
      error: c.oweText,
      onError: c.bg,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.bgSubtle,
      surfaceContainer: c.surfaceMuted,
      surfaceContainerHigh: c.chip,
      surfaceContainerHighest: c.chip,
      outline: c.divider,
      outlineVariant: c.border,
      shadow: c.shadow,
      scrim: c.scrim,
      inverseSurface: c.ink,
      onInverseSurface: c.onInk,
      inversePrimary: c.primaryDisabled,
      surfaceTint: c.surface,
    );
    final overlay = isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: AppFonts.sans,
      textTheme: text.toTextTheme(),
      extensions: [c, text],
      splashFactory: InkRipple.splashFactory,
      dividerColor: c.divider,
      iconTheme: IconThemeData(color: c.textPrimary, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.title,
        systemOverlayStyle: overlay.copyWith(statusBarColor: AppPalette.clear),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        modalBarrierColor: c.scrim,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        modalElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: text.bodySmall.copyWith(color: c.onInk),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.all16),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primaryContainer,
        selectionHandleColor: c.primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.ink, borderRadius: AppRadii.all16),
        textStyle: text.caption.copyWith(color: c.onInk),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      focusColor: c.primaryContainer,
      highlightColor: AppPalette.clear,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: PredictiveBackPageTransitionsBuilder()},
      ),
    );
  }
}
