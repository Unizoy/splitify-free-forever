import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:splitify/core/money/amount_expression.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// UI text for the expense screens: categories, split kinds, error codes and the live split footer.
extension ExpenseCopy on AppLocalizations {
  /// Text for a parent (`food`) or sub category key (`food.snacks`).
  String category(String key) => switch (key) {
    'food' => catFood,
    'groceries' => catGroceries,
    'travel' => catTravel,
    'rent' => catRent,
    'utilities' => catUtilities,
    'shopping' => catShopping,
    'entertainment' => catEntertainment,
    'other' => catOther,
    'food.dining_out' => catFoodDiningOut,
    'food.takeaway' => catFoodTakeaway,
    'food.snacks' => catFoodSnacks,
    'groceries.groceries' => catGroceriesGroceries,
    'groceries.household' => catGroceriesHousehold,
    'travel.flights' => catTravelFlights,
    'travel.train_bus' => catTravelTrainBus,
    'travel.cab_auto' => catTravelCabAuto,
    'travel.fuel' => catTravelFuel,
    'travel.hotel' => catTravelHotel,
    'travel.parking_tolls' => catTravelParkingTolls,
    'rent.rent' => catRentRent,
    'rent.maintenance' => catRentMaintenance,
    'utilities.electricity' => catUtilitiesElectricity,
    'utilities.water' => catUtilitiesWater,
    'utilities.gas' => catUtilitiesGas,
    'utilities.internet_phone' => catUtilitiesInternetPhone,
    'utilities.subscriptions' => catUtilitiesSubscriptions,
    'shopping.clothing' => catShoppingClothing,
    'shopping.electronics' => catShoppingElectronics,
    'shopping.gifts' => catShoppingGifts,
    'shopping.other' => catShoppingOther,
    'entertainment.movies' => catEntertainmentMovies,
    'entertainment.events' => catEntertainmentEvents,
    'entertainment.games' => catEntertainmentGames,
    'entertainment.sports' => catEntertainmentSports,
    'other.medical' => catOtherMedical,
    'other.education' => catOtherEducation,
    'other.services' => catOtherServices,
    _ => catOtherGeneral,
  };

  /// Name of a split kind ("Equally", "Shares").
  String splitKind(SplitKind kind) => switch (kind) {
    SplitKind.equal => expSplitEqual,
    SplitKind.exact => expSplitExact,
    SplitKind.percent => expSplitPercent,
    SplitKind.shares => expSplitShares,
    SplitKind.adjust => expSplitAdjust,
  };

  /// One-line help under the split-kind picker.
  String splitHint(SplitKind kind) => switch (kind) {
    SplitKind.equal => expSplitEqualHint,
    SplitKind.exact => expSplitExactHint,
    SplitKind.percent => expSplitPercentHint,
    SplitKind.shares => expSplitSharesHint,
    SplitKind.adjust => expSplitAdjustHint,
  };

  /// Error under the amount, or null while there is nothing wrong (empty or still typing).
  String? amountError(AmountResult r, String currency) => switch (r) {
    AmountOk() || AmountEmpty() || AmountIncomplete() => null,
    AmountTooManyDecimals(:final maxDecimals) => expAmountErrorDecimals(currency, maxDecimals),
    AmountDivisionByZero() => expAmountErrorDivide,
    AmountNotPositive() => expAmountErrorNotPositive,
    AmountTooLarge() => expAmountErrorTooLarge,
    AmountInvalid() => expAmountErrorInvalid,
  };

  /// Description problem text.
  String? descriptionError(DescriptionProblem? p) => switch (p) {
    null => null,
    DescriptionProblem.missing => expDescriptionMissing,
    DescriptionProblem.tooLong => expDescriptionTooLong,
  };
}

/// The live footer under a split editor: text plus whether it is an error (05 §4, #5–9).
typedef SplitFooter = ({String text, bool error});

/// Footer for [split] against [total] minor units of [currency] (null total = no amount yet).
/// [nameOf] names a member for the "x's share can't go below ₹0" error.
SplitFooter splitFooter(
  AppLocalizations l,
  SplitDraft split,
  int? total,
  String currency, {
  required String Function(String memberId) nameOf,
  bool percentOnly = false,
}) {
  String money(int v) => MoneyFormatter.list.format(v, currency);
  final check = split.check(percentOnly ? 10000 : total);
  final people = split.participants.length;
  if (check is SplitReady) {
    return switch (split.kind) {
      SplitKind.equal => (
        text: total == null || percentOnly
            ? l.expFooterPeople(people)
            : l.expFooterEqual(people, money(check.shares.values.first)),
        error: false,
      ),
      SplitKind.exact => (text: l.expFooterDone(money(total ?? 0)), error: false),
      SplitKind.percent => (text: l.expFooterPercentDone, error: false),
      SplitKind.shares => (
        text: l.expFooterShares(ScaledInput.format(split.valueSum, 3)),
        error: false,
      ),
      SplitKind.adjust => (
        text: l.expFooterAdjust(money((total ?? 0) - split.valueSum)),
        error: false,
      ),
    };
  }
  final invalid = check as SplitInvalid;
  final zero = money(0);
  // The Items split (D-034 A2) explains its own problems.
  final items = split.isItems
      ? switch (invalid.code) {
          'NO_PARTICIPANTS' => l.entryItemsNoPeople,
          'NO_SHARES' => l.entryItemsNone,
          'NEGATIVE_SHARE' ||
          'AMOUNT_NOT_POSITIVE' when total != null => l.entryItemsDiscountTooBig,
          SplitInvalid.itemsTooLarge => l.entryItemsTooMany,
          _ => null,
        }
      : null;
  if (items != null) return (text: items, error: true);
  final text = switch (invalid.code) {
    'AMOUNT_NOT_POSITIVE' => l.expErrNeedAmount,
    'NO_PARTICIPANTS' => l.expErrNoParticipants,
    'NO_SHARES' => l.expErrNoShares,
    'PERCENT_OUT_OF_RANGE' => l.expErrPercentRange,
    'ADJUSTMENTS_EXCEED_TOTAL' => l.expErrAdjustOver(money(-invalid.amount)),
    SplitInvalid.invalidInput => l.expErrInvalidInput,
    'SUM_MISMATCH' =>
      invalid.amount > 0
          ? l.expFooterLeft(money(split.valueSum), money(total ?? 0), money(invalid.amount))
          : l.expFooterOver(money(split.valueSum), money(total ?? 0), money(-invalid.amount)),
    'PERCENT_SUM_MISMATCH' =>
      invalid.amount > 0
          ? l.expFooterPercentLeft(
              ScaledInput.format(split.valueSum, 2),
              ScaledInput.format(invalid.amount, 2),
            )
          : l.expFooterPercentOver(
              ScaledInput.format(split.valueSum, 2),
              ScaledInput.format(-invalid.amount, 2),
            ),
    'NEGATIVE_SHARE' => switch (total == null ? null : split.negativeMember(total)) {
      final String id => l.expErrNegativeShare(nameOf(id), zero),
      null => l.expErrNegativeShareAny(zero),
    },
    _ => l.expErrGeneric,
  };
  return (text: text, error: true);
}

/// Category row value: "Food · Dining out", or just "Rent" when the sub-category has the same name.
String categoryValue(AppLocalizations l, String key) {
  final parent = l.category(categoryOf(key).name);
  final sub = l.category(key);
  return sub == parent ? parent : '$parent\u00A0· $sub';
}

/// Icon category of a stored key (`travel.fuel` → travel).
Category categoryOf(String key) => Category.values.byName(ExpenseCategories.parentOf(key));

/// Joins the words of a date or time with no-break spaces, so "21 Nov 2026" or "9:05 PM" never wraps
/// in the middle.
String unbroken(String text) => text.replaceAll(' ', '\u00A0');

/// "21 Nov 2026" for a local calendar date (never wraps inside).
String shortDate(BuildContext context, DateTime d) =>
    unbroken(DateFormat('d MMM y', Localizations.localeOf(context).toLanguageTag()).format(d));

/// "21 Nov" (list rows; the month header carries the year).
String dayMonth(BuildContext context, DateTime d) =>
    unbroken(DateFormat('d MMM', Localizations.localeOf(context).toLanguageTag()).format(d));

/// "NOVEMBER 2026" header text for the month of [d].
String monthHeader(BuildContext context, DateTime d) =>
    DateFormat('MMMM y', Localizations.localeOf(context).toLanguageTag()).format(d);
