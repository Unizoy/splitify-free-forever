import 'package:flutter/widgets.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Which way money flows for the viewer: green when owed, red when owing,
/// neutral when settled (PLAN.md, §2).
enum MoneyTone {
  owed,
  owe,
  settled;

  /// Text colour on light/dark backgrounds.
  Color textColor(AppColors c) => switch (this) {
    MoneyTone.owed => c.owedText,
    MoneyTone.owe => c.oweText,
    MoneyTone.settled => c.settled,
  };

  /// Text colour on dark imagery (covers, glass, navy cards).
  Color onDarkColor(AppColors c) => switch (this) {
    MoneyTone.owed => c.owedOnDark,
    MoneyTone.owe => c.oweOnDark,
    MoneyTone.settled => c.onHeroMuted,
  };

  /// Sign shown before an amount: "+" owed, "−" (U+2212) owe, none settled.
  String get sign => switch (this) {
    MoneyTone.owed => '+',
    MoneyTone.owe => '−',
    MoneyTone.settled => '',
  };
}
