import 'package:flutter/widgets.dart';
import 'package:splitify/ui/theme/app_colors.dart';

/// Every icon the app uses, in one place (§8): Phosphor icons (MIT), from the
/// bundled `assets/fonts/Phosphor-*.ttf` (S-008: the phosphor_flutter package
/// does not compile on Flutter 3.50, so the fonts are vendored).
abstract final class AppIcons {
  static const _regular = 'PhosphorRegular';
  static const _bold = 'PhosphorBold';
  static const _fill = 'PhosphorFill';

  // Navigation
  static const IconData groups = IconData(0xe68e, fontFamily: _regular);
  static const IconData groupsActive = IconData(0xe68e, fontFamily: _fill);
  static const IconData friends = IconData(0xea8c, fontFamily: _regular);
  static const IconData friendsActive = IconData(0xea8c, fontFamily: _fill);
  static const IconData activity = IconData(0xe2de, fontFamily: _regular);
  static const IconData activityActive = IconData(0xe2de, fontFamily: _fill);
  static const IconData account = IconData(0xe4c4, fontFamily: _regular);
  static const IconData add = IconData(0xe3d4, fontFamily: _bold);
  static const IconData back = IconData(0xe058, fontFamily: _regular);
  static const IconData backChevron = IconData(0xe138, fontFamily: _bold);
  static const IconData chevronRight = IconData(0xe13a, fontFamily: _bold);
  static const IconData chevronDown = IconData(0xe136, fontFamily: _bold);
  static const IconData close = IconData(0xe4f6, fontFamily: _regular);
  static const IconData home = IconData(0xe2c2, fontFamily: _fill);
  static const IconData settings = IconData(0xe272, fontFamily: _fill);
  static const IconData search = IconData(0xe30c, fontFamily: _regular);
  static const IconData bell = IconData(0xe0ce, fontFamily: _regular);
  static const IconData share = IconData(0xe408, fontFamily: _regular);
  static const IconData qr = IconData(0xe3e6, fontFamily: _regular);

  // Status
  static const IconData check = IconData(0xe182, fontFamily: _bold);
  static const IconData checkCircle = IconData(0xe184, fontFamily: _fill);
  static const IconData shieldCheck = IconData(0xe40c, fontFamily: _regular);
  static const IconData shieldCheckFill = IconData(0xe40c, fontFamily: _fill);
  static const IconData unsynced = IconData(0xe1b6, fontFamily: _regular);
  static const IconData synced = IconData(0xe1b0, fontFamily: _regular);
  static const IconData info = IconData(0xe2ce, fontFamily: _regular);
  static const IconData warning = IconData(0xe4e2, fontFamily: _regular);
  static const IconData minus = IconData(0xe32a, fontFamily: _regular);
  static const IconData plus = IconData(0xe3d4, fontFamily: _regular);
  static const IconData sparkle = IconData(0xe6a2, fontFamily: _fill);

  // Steps (add expense)
  static const IconData stepAmount = IconData(0xe558, fontFamily: _regular);
  static const IconData stepPaidBy = IconData(0xe4c2, fontFamily: _regular);
  static const IconData stepSplit = IconData(0xe158, fontFamily: _regular);
  static const IconData stepDetails = IconData(0xe47a, fontFamily: _regular);
  static const IconData stepReview = IconData(0xe184, fontFamily: _regular);

  // Things
  static const IconData wallet = IconData(0xe68a, fontFamily: _regular);
  static const IconData receipt = IconData(0xe3ec, fontFamily: _regular);
  static const IconData calendar = IconData(0xe10a, fontFamily: _regular);
  static const IconData chat = IconData(0xe16c, fontFamily: _regular);
  static const IconData coins = IconData(0xe78e, fontFamily: _regular);
  static const IconData chart = IconData(0xe158, fontFamily: _fill);
  static const IconData globe = IconData(0xe28a, fontFamily: _fill);
  static const IconData user = IconData(0xe4c2, fontFamily: _regular);
  static const IconData userFill = IconData(0xe4c4, fontFamily: _fill);
  static const IconData sun = IconData(0xe472, fontFamily: _regular);
  static const IconData moon = IconData(0xe330, fontFamily: _regular);
  static const IconData device = IconData(0xe1e0, fontFamily: _regular);
  static const IconData palette = IconData(0xe6a2, fontFamily: _fill);
  static const IconData sync = IconData(0xe094, fontFamily: _regular);
  static const IconData trash = IconData(0xe4a6, fontFamily: _regular);
  static const IconData signOut = IconData(0xe42a, fontFamily: _regular);
  static const IconData licence = IconData(0xe2ce, fontFamily: _regular);

  // Group types
  static const IconData typeTrip = IconData(0xe5d6, fontFamily: _fill);
  static const IconData typeHome = IconData(0xe2c4, fontFamily: _fill);
  static const IconData typeCouple = IconData(0xe2a8, fontFamily: _fill);
  static const IconData typeOther = IconData(0xec5e, fontFamily: _fill);
  static const IconData typeDirect = IconData(0xe4c2, fontFamily: _fill);

  // Categories (D-016)
  static const IconData food = IconData(0xe262, fontFamily: _fill);
  static const IconData groceries = IconData(0xe964, fontFamily: _fill);
  static const IconData travel = IconData(0xe5d6, fontFamily: _fill);
  static const IconData rent = IconData(0xe2c2, fontFamily: _fill);
  static const IconData utilities = IconData(0xe2dc, fontFamily: _fill);
  static const IconData shopping = IconData(0xe416, fontFamily: _fill);
  static const IconData entertainment = IconData(0xe8c2, fontFamily: _fill);
  static const IconData otherCategory = IconData(0xe47a, fontFamily: _fill);
}

/// Starting categories with their icon and colour (D-016, §2).
enum Category {
  food(AppIcons.food, AppPalette.food),
  groceries(AppIcons.groceries, AppPalette.groceries),
  travel(AppIcons.travel, AppPalette.travel),
  rent(AppIcons.rent, AppPalette.rent),
  utilities(AppIcons.utilities, AppPalette.utilities),
  shopping(AppIcons.shopping, AppPalette.shopping),
  entertainment(AppIcons.entertainment, AppPalette.entertainment),
  other(AppIcons.otherCategory, AppPalette.other);

  const Category(this.icon, this.color);

  final IconData icon;
  final Color color;
}
