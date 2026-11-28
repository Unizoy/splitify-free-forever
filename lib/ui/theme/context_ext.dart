import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/app_colors.dart';
import 'package:splitify/ui/theme/app_spacing.dart';
import 'package:splitify/ui/theme/app_motion.dart';
import 'package:splitify/ui/theme/app_text.dart';

/// Short access to the design tokens: `context.colors`, `context.text`,
/// `context.motion`, `context.isDark`.
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;

  AppText get text => Theme.of(this).extension<AppText>() ?? AppText.withColor(colors.textPrimary);

  AppMotion get motion => AppMotion.of(this);

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Whether rows put their trailing amount or action under the text: the screen is narrow for the text
  /// size, under 250 dp of width per unit of text scale (320 dp at 1.3, 412 dp at 1.7; tablets count as
  /// their content width). Width-based, so a small phone at 1.3 stacks and a big one at 1.5 does not
  /// (R3-A, S-446).
  bool get stackRows {
    final width = math.min(
      MediaQuery.sizeOf(this).width,
      AppSpacing.maxContent + 2 * AppSpacing.screen,
    );
    return width / MediaQuery.textScalerOf(this).scale(1) < 250;
  }
}
