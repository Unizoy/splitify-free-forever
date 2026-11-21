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

  @override
  String get signInTitle => 'How would you like to sign in?';

  @override
  String get signInSubtitle =>
      'Use Google or get a 6-digit code by email. The same email is always the same account.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get googleSoon => 'Google sign-in is coming soon. Use your email for now.';

  @override
  String get orDivider => 'or';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get sendCode => 'Send code';

  @override
  String get devSignIn => 'Developer sign-in';

  @override
  String get codeTitle => 'Enter the 6-digit code';

  @override
  String codeSentTo(String email) {
    return 'We sent it to $email. It works for 10 minutes.';
  }

  @override
  String codeBoxes(int count) {
    return '6-digit code, $count of 6 entered';
  }

  @override
  String resendIn(int seconds) {
    return 'Resend code in $seconds s';
  }

  @override
  String get resendCode => 'Resend code';

  @override
  String get changeEmail => 'Change email';

  @override
  String get verifyCode => 'Verify';

  @override
  String get profileConfirmTitle => 'What should friends call you?';

  @override
  String get profileConfirmSubtitle =>
      'Your name, photo and UPI ID are shown to people in your groups.';

  @override
  String get nameLabel => 'Your name';

  @override
  String get upiLabel => 'UPI ID (optional)';

  @override
  String get upiHint => 'name@bank';

  @override
  String get scanUpiQr => 'Scan my UPI QR';

  @override
  String get continueLabel => 'Continue';

  @override
  String get authErrorInvalidCode => 'That code is not right. Check it and try again.';

  @override
  String get authErrorExpiredCode => 'This code has expired or is not right. Request a new code.';

  @override
  String get authErrorTooManyTries => 'Too many tries, request a new code';

  @override
  String get authErrorInvalidEmail => 'Enter an email like name@example.com';

  @override
  String get authErrorOffline => 'You’re offline — connect once to sign in';

  @override
  String get authErrorCancelled => 'Sign-in was cancelled';

  @override
  String get authErrorNotConfigured => 'Sign-in is not set up in this build yet';

  @override
  String get authErrorInvalidCredentials => 'Wrong email or password';

  @override
  String get authErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String get devLoginSubtitle =>
      'Debug builds only. Signs in a test user and creates it on first use.';

  @override
  String devLoginUser(String user) {
    return 'Test user $user';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSubtitle => 'Name, photo, UPI ID, currency';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get defaultCurrency => 'Default currency';

  @override
  String get defaultCurrencyHint => 'Used for new groups';

  @override
  String get saveLabel => 'Save';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get needsInternet => 'Needs internet. Connect and try again.';

  @override
  String get nameInvalid => 'Enter your name (1 to 50 letters)';

  @override
  String get upiInvalid => 'Enter a UPI ID like name@bank';

  @override
  String get upiQrInvalid => 'That QR is not a UPI payment code';

  @override
  String get scanUpiHint => 'Point the camera at the QR code in your UPI app.';

  @override
  String get chooseCurrency => 'Choose currency';

  @override
  String get notSet => 'Not set';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutBody =>
      'Splitify removes your data from this phone. Your groups stay safe on the server.';

  @override
  String get cancelLabel => 'Cancel';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete your account';

  @override
  String get deleteAccountBody =>
      'Your expenses stay in your groups under your name so balances stay right; your profile, photo, UPI ID and sign-in are removed.';

  @override
  String get deleteAccountWarning => 'This works only online and cannot be undone.';

  @override
  String get typeDeleteLabel => 'Type DELETE to confirm';

  @override
  String get deleteWord => 'DELETE';

  @override
  String get deleteAccountButton => 'Delete my account';

  @override
  String get deleteAccountFailed =>
      'Could not delete your account. Check your connection and try again.';

  @override
  String get syncStorage => 'Sync & storage';

  @override
  String get syncStorageHint => 'Changes are saved on this phone first, then sent to your groups.';

  @override
  String get syncStateSynced => 'Everything is synced';

  @override
  String syncStateWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to sync',
      one: '1 change waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get syncStateOffline => 'You are offline';

  @override
  String get syncStateOfflineHint =>
      'Changes stay on this phone and sync when you are back online.';

  @override
  String syncStateFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes need attention',
      one: '1 change needs attention',
    );
    return '$_temp0';
  }

  @override
  String get syncStateError => 'Sync did not finish. It tries again soon.';

  @override
  String get syncStateSignedOut => 'Sign in again to sync';

  @override
  String lastSyncLine(String when) {
    return 'Last sync $when';
  }

  @override
  String get lastSyncNever => 'never';

  @override
  String get lastSyncJustNow => 'just now';

  @override
  String lastSyncMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String lastSyncHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String lastSyncOn(String date) {
    return 'on $date';
  }

  @override
  String get syncWaitingLabel => 'Waiting';

  @override
  String get syncFailedLabel => 'Need attention';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncIssuesTitle => 'Needs attention';

  @override
  String syncIssueEntity(String entity) {
    String _temp0 = intl.Intl.selectLogic(entity, {
      'group': 'Group',
      'member': 'Member',
      'expense': 'Expense',
      'payment': 'Payment',
      'comment': 'Comment',
      'other': 'Change',
    });
    return '$_temp0';
  }

  @override
  String syncIssueOp(String op) {
    String _temp0 = intl.Intl.selectLogic(op, {
      'delete': 'Delete',
      'restore': 'Restore',
      'other': 'Edit',
    });
    return '$_temp0';
  }

  @override
  String syncIssueTries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tried $count times',
      one: 'Tried once',
    );
    return '$_temp0';
  }

  @override
  String get syncErrorNotMember => 'You are no longer in this group.';

  @override
  String get syncErrorRejected => 'The server did not accept this change.';

  @override
  String syncErrorCode(String code) {
    return 'Code $code';
  }

  @override
  String get retryLabel => 'Retry';

  @override
  String get discardLabel => 'Discard';

  @override
  String get discardTitle => 'Discard this change?';

  @override
  String get discardBody => 'It is removed from this phone and the copy on the server comes back.';

  @override
  String get onThisPhone => 'On this phone';

  @override
  String get exportDebugLog => 'Export debug log';

  @override
  String get debugLogSubject => 'Splitify debug log';

  @override
  String get syncRowSynced => 'Synced';

  @override
  String syncRowWaiting(int count) {
    return '$count waiting';
  }

  @override
  String syncRowProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problems',
      one: '1 problem',
    );
    return '$_temp0';
  }
}
