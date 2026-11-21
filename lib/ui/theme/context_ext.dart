import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/app_colors.dart';
import 'package:splitify/ui/theme/app_motion.dart';
import 'package:splitify/ui/theme/app_text.dart';

/// Short access to the design tokens: `context.colors`, `context.text`,
/// `context.motion`, `context.isDark`.
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;

  AppText get text => Theme.of(this).extension<AppText>() ?? AppText.withColor(colors.textPrimary);

  AppMotion get motion => AppMotion.of(this);

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
