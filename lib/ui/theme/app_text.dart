import 'package:flutter/material.dart';

/// Bundled font families (assets/fonts, SIL OFL 1.1).
abstract final class AppFonts {
  static const serif = 'InstrumentSerif';
  static const sans = 'Inter';
}

/// Type scale (planning/06-design-system.md §3) as a [ThemeExtension].
///
/// Styles carry the default text colour of the mode; override with
/// `copyWith(color: …)`. Change weights with [TextStyleWeight.w] so the
/// variable Inter font follows (it needs a `wght` font variation).
@immutable
class AppText extends ThemeExtension<AppText> {
  const AppText({
    required this.heroDisplay,
    required this.sheetTitle,
    required this.cardTitle,
    required this.headline,
    required this.title,
    required this.body,
    required this.bodySmall,
    required this.caption,
    required this.labelCaps,
    required this.amountHero,
    required this.amount,
    required this.button,
    required this.displayLarge,
    required this.amountLarge,
    required this.labelCapsLarge,
    required this.input,
  });

  /// Builds the scale with [primary] as the default colour.
  factory AppText.withColor(Color primary) => AppText(
    // One step smaller and a touch tighter than phase 02 (S-268, owner D-027, Atlys refs 438/602).
    heroDisplay: _serif(34, 38, -0.5, primary),
    sheetTitle: _serif(28, 32, -0.3, primary),
    cardTitle: _serif(19, 23, -0.1, primary),
    headline: _sans(20, 26, 700, -0.3, primary),
    title: _sans(16, 22, 600, -0.1, primary),
    body: _sans(15, 21, 400, -0.1, primary),
    bodySmall: _sans(13, 18, 400, 0, primary),
    caption: _sans(11.5, 15, 500, 0.2, primary),
    labelCaps: _sans(11, 14, 700, 1.4, primary),
    amountHero: _sans(34, 38, 700, -0.8, primary, tabular: true),
    amount: _sans(15, 20, 600, -0.1, primary, tabular: true),
    button: _sans(16, 20, 600, -0.1, primary),
    // R3-A (S-442): the few sizes features used to set by hand, now named once.
    displayLarge: _serif(42, 44, -0.6, primary),
    amountLarge: _sans(26, 30, 700, -0.6, primary, tabular: true),
    labelCapsLarge: _sans(13, 16, 700, 1.8, primary),
    input: _sans(16, 22, 400, -0.1, primary),
  );

  /// Serif display: hero headlines, lowercase sentences.
  final TextStyle heroDisplay;

  /// Serif: bottom-sheet and screen titles.
  final TextStyle sheetTitle;

  /// Serif, shown UPPERCASE: group card names.
  final TextStyle cardTitle;

  /// Step questions ("Who paid?").
  final TextStyle headline;
  final TextStyle title;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle caption;

  /// Letter-spaced, shown UPPERCASE: "YOU ARE OWED", field labels.
  final TextStyle labelCaps;

  /// Big tabular amount (glass card, wallet, gauge).
  final TextStyle amountHero;

  /// Tabular list amount.
  final TextStyle amount;
  final TextStyle button;

  /// Serif statement (welcome headline, settle-up celebration).
  final TextStyle displayLarge;

  /// Mid-size tabular number (stat tiles, sign-in code boxes).
  final TextStyle amountLarge;

  /// Bigger letter-spaced caps (showpiece card headers, wallet brand and status).
  final TextStyle labelCapsLarge;

  /// Text typed into fields.
  final TextStyle input;

  /// Serif hero text never scales beyond this factor (§3).
  static const maxSerifScale = 1.6;

  static TextStyle _serif(double size, double line, double spacing, Color color) => TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: size,
    height: line / size,
    letterSpacing: spacing,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle _sans(
    double size,
    double line,
    int weight,
    double spacing,
    Color color, {
    bool tabular = false,
  }) => TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: size,
    height: line / size,
    letterSpacing: spacing,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation.weight(weight.toDouble())],
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    color: color,
  );

  List<TextStyle> get _all => [
    heroDisplay,
    sheetTitle,
    cardTitle,
    headline,
    title,
    body,
    bodySmall,
    caption,
    labelCaps,
    amountHero,
    amount,
    button,
    displayLarge,
    amountLarge,
    labelCapsLarge,
    input,
  ];

  /// Material text theme built from the same styles, so stock widgets match.
  TextTheme toTextTheme() => TextTheme(
    displayLarge: heroDisplay,
    displayMedium: sheetTitle,
    displaySmall: cardTitle,
    headlineMedium: sheetTitle,
    headlineSmall: headline,
    titleLarge: title,
    titleMedium: body.w(600),
    titleSmall: bodySmall.w(600),
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: bodySmall,
    labelLarge: button,
    labelMedium: caption,
    labelSmall: caption,
  );

  @override
  AppText copyWith() => this;

  @override
  AppText lerp(ThemeExtension<AppText>? other, double t) {
    if (other is! AppText) return this;
    final a = _all;
    final b = other._all;
    final v = [for (var i = 0; i < a.length; i++) TextStyle.lerp(a[i], b[i], t)!];
    return AppText(
      heroDisplay: v[0],
      sheetTitle: v[1],
      cardTitle: v[2],
      headline: v[3],
      title: v[4],
      body: v[5],
      bodySmall: v[6],
      caption: v[7],
      labelCaps: v[8],
      amountHero: v[9],
      amount: v[10],
      button: v[11],
      displayLarge: v[12],
      amountLarge: v[13],
      labelCapsLarge: v[14],
      input: v[15],
    );
  }
}

/// Weight changes that keep the variable font in sync.
extension TextStyleWeight on TextStyle {
  /// Same style with weight [weight] (100–900).
  TextStyle w(int weight) => copyWith(
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation.weight(weight.toDouble())],
  );
}
