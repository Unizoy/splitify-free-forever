// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Splitify Free Forever';

  @override
  String get envErrorTitle => 'App is not configured';

  @override
  String get loading => 'Loading';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get back => 'Back';

  @override
  String get home => 'Home';

  @override
  String get close => 'Close';

  @override
  String get search => 'Search';

  @override
  String get notifications => 'Notifications';

  @override
  String get settings => 'Settings';

  @override
  String get required => 'required';

  @override
  String get increase => 'Increase';

  @override
  String get decrease => 'Decrease';

  @override
  String moreCount(int count) {
    return '+$count';
  }

  @override
  String moreMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more people',
      one: '1 more person',
    );
    return '$_temp0';
  }

  @override
  String pageDots(int index, int total) {
    return '$index of $total';
  }

  @override
  String gaugeSemantics(int percent) {
    return '$percent percent';
  }

  @override
  String get navGroups => 'Groups';

  @override
  String get navFriends => 'Friends';

  @override
  String get navActivity => 'Activity';

  @override
  String get navAccount => 'Account';

  @override
  String get addExpense => 'Add expense';

  @override
  String get notSyncedYet => 'Not synced yet';

  @override
  String get notSyncedYetHint => 'Saved on this phone. It syncs when you are back online.';

  @override
  String get youAreOwed => 'You are owed';

  @override
  String get youOwe => 'You owe';

  @override
  String get settled => 'Settled';

  @override
  String get allSettled => 'All settled';

  @override
  String get settleUp => 'Settle up';

  @override
  String get overall => 'Overall';

  @override
  String get welcomeLead => 'split it.';

  @override
  String get welcomeHighlight => 'settle it.';

  @override
  String get welcomeBadge => 'Free forever · no ads';

  @override
  String get getStarted => 'Get\nstarted';

  @override
  String get welcomeFooter => 'Open source · made in India';

  @override
  String get groupsHero => 'split it.\nsettle it.';

  @override
  String get noGroupsYet => 'No groups yet';

  @override
  String get glassEmptyHint => 'Add a group to start splitting bills.';

  @override
  String get createGroup => 'Create a group';

  @override
  String get joinGroup => 'Join a group';

  @override
  String get newShort => 'New';

  @override
  String get newGroup => 'New group';

  @override
  String get joinGroupShort => 'Join group';

  @override
  String get joinShort => 'Join';

  @override
  String activeGroups(int count) {
    return 'Active groups · $count';
  }

  @override
  String get emptyGroupsTitle => 'Create your first group';

  @override
  String get emptyGroupsBody => 'Trips, flatmates, couples — add the people you split with.';

  @override
  String get friendsHero => 'your people,\nsquared up.';

  @override
  String get emptyFriendsTitle => 'No friends yet';

  @override
  String get emptyFriendsBody => 'People you share a group with show up here.';

  @override
  String get activityHero => 'every rupee,\naccounted for.';

  @override
  String get emptyActivityTitle => 'No activity yet';

  @override
  String get emptyActivityBody => 'Expenses, payments and comments show up here.';

  @override
  String get you => 'You';

  @override
  String get yourAccount => 'Your account';

  @override
  String get accountSettings => 'Account settings';

  @override
  String get walletBrand => 'SPLITIFY';

  @override
  String get overallBalance => 'Overall balance';

  @override
  String get zeroRupees => '₹0';

  @override
  String acrossGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Across $count groups',
      one: 'Across 1 group',
      zero: 'No groups yet',
    );
    return '$_temp0';
  }

  @override
  String get yourSpending => 'Your spending';

  @override
  String get yourStats => 'Your stats';

  @override
  String get statThisMonth => 'Spent this\nmonth';

  @override
  String get statGroups => 'Active\ngroups';

  @override
  String get statPeople => 'People you\nsplit with';

  @override
  String get statExpenses => 'Expenses\nadded';

  @override
  String get preferences => 'Preferences';

  @override
  String get preferencesSubtitle => 'Appearance';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceHint => 'Choose how Splitify looks. System follows your phone\'s setting.';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get aboutLicences => 'About & licences';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get celebrationLead => 'all';

  @override
  String get celebrationHighlight => 'settled';

  @override
  String get syncing => 'Syncing…';

  @override
  String get stepAmount => 'Amount';

  @override
  String get stepPaidBy => 'Paid by';

  @override
  String get stepSplit => 'Split';

  @override
  String get stepDetails => 'Details';

  @override
  String get stepReview => 'Review';

  @override
  String stepDone(String label) {
    return '$label, done';
  }

  @override
  String stepCurrent(String label) {
    return '$label, current step';
  }
}
