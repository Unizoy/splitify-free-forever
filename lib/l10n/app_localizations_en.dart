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
  String get archivedGroups => 'Archived groups';

  @override
  String get groupsOffline => 'You\'re offline. Changes sync when you\'re back.';

  @override
  String get groupsLoading => 'Loading your groups';

  @override
  String get editGroup => 'Edit group';

  @override
  String get groupFormSubtitle => 'Give it a name and pick what it is for.';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get groupNameHint => 'Goa trip, Flat 4B…';

  @override
  String get groupNameRequired => 'Enter a group name';

  @override
  String get groupNameTooLong => 'Keep the name under 60 letters';

  @override
  String get groupTypeLabel => 'Type';

  @override
  String get groupTypeTrip => 'Trip';

  @override
  String get groupTypeHome => 'Home';

  @override
  String get groupTypeCouple => 'Couple';

  @override
  String get groupTypeOther => 'Other';

  @override
  String get mainCurrency => 'Main currency';

  @override
  String get mainCurrencyHint =>
      'Default for new expenses. Expenses already added keep their currency.';

  @override
  String get coverHint => 'Every group gets its own generated cover.';

  @override
  String get createGroupButton => 'Create group';

  @override
  String get groupSaved => 'Group saved';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get groupTabExpenses => 'Expenses';

  @override
  String get groupTabBalances => 'Balances';

  @override
  String get groupTabTotals => 'Totals';

  @override
  String get groupNoExpensesTitle => 'No expenses yet';

  @override
  String get groupNoExpensesBody => 'Add the first bill and Splitify splits it for you.';

  @override
  String get groupBalancesEmptyTitle => 'Balances show up here';

  @override
  String get groupBalancesEmptyBody => 'Once the group has expenses, you see who owes whom.';

  @override
  String get groupTotalsEmptyTitle => 'Totals show up here';

  @override
  String get groupTotalsEmptyBody =>
      'Total spent and each person\'s share, once there are expenses.';

  @override
  String get groupArchivedBanner => 'This group is archived. Unarchive it to add expenses.';

  @override
  String get groupNotFound => 'This group is not on this phone.';

  @override
  String get archiveGroup => 'Archive group';

  @override
  String get unarchiveGroup => 'Unarchive';

  @override
  String get groupArchivedDone => 'Group archived';

  @override
  String get groupUnarchivedDone => 'Group is active again';

  @override
  String get groupSettingsTitle => 'Group settings';

  @override
  String get membersSection => 'Members';

  @override
  String get addMember => 'Add member';

  @override
  String get addMemberHint => 'Add someone by name. They can join later and claim this spot.';

  @override
  String get memberNameLabel => 'Name';

  @override
  String get memberNameInvalid => 'Enter a name (1 to 50 letters)';

  @override
  String get memberColour => 'Colour';

  @override
  String memberColourOption(int index) {
    return 'Colour $index';
  }

  @override
  String get memberOwner => 'Owner';

  @override
  String get memberNameOnly => 'Not joined yet';

  @override
  String get memberClaimed => 'Claimed this spot';

  @override
  String memberYouSuffix(String name) {
    return '$name (you)';
  }

  @override
  String get renameMember => 'Rename';

  @override
  String get unlinkMember => 'Unlink account';

  @override
  String unlinkMemberTitle(String name) {
    return 'Unlink $name?';
  }

  @override
  String get unlinkMemberBody =>
      'This spot becomes name-only again and keeps all its expenses. Use it when the wrong person claimed it.';

  @override
  String get removeMember => 'Remove from group';

  @override
  String removeMemberTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeMemberBody => 'This works only when they are settled up in every currency.';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String get leaveGroupTitle => 'Leave this group?';

  @override
  String get leaveGroupBody =>
      'You can leave once you are settled up. Join again any time with the invite code.';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get deleteGroupTitle => 'Delete this group?';

  @override
  String get deleteGroupBody =>
      'Everyone loses access. You can restore it for 30 days from Account → Deleted groups.';

  @override
  String get groupDeletedDone => 'Group deleted';

  @override
  String get groupErrorNonzeroBalance =>
      'Settle up first. This person still has a balance in this group.';

  @override
  String get groupErrorNotMember => 'You\'re not a member of this group any more.';

  @override
  String get groupErrorGroupFull => 'This group already has 100 members.';

  @override
  String get groupErrorAlreadyClaimed => 'Someone already claimed that spot. Pick another one.';

  @override
  String get groupErrorMemberNotFound => 'That person is no longer in this group.';

  @override
  String get groupErrorNotClaimed => 'That spot is not linked to an account.';

  @override
  String get groupErrorClaimRequired => 'Pick your name to join this group.';

  @override
  String get deletedGroups => 'Deleted groups';

  @override
  String get deletedGroupsBody => 'Groups you deleted. Restore one within 30 days.';

  @override
  String get deletedGroupsEmpty => 'No deleted groups';

  @override
  String get deletedGroupsEmptyBody => 'Groups you delete show up here for 30 days.';

  @override
  String get restore => 'Restore';

  @override
  String restoreDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'Last day to restore',
    );
    return '$_temp0';
  }

  @override
  String get groupRestoredDone => 'Group restored';

  @override
  String get restoreExpired => 'Too late to restore';

  @override
  String get invitePeople => 'Invite people';

  @override
  String get inviteBody => 'Friends scan this QR or type the code in Groups → Join.';

  @override
  String inviteQrLabel(String code) {
    return 'QR code for invite code $code';
  }

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get shareInvite => 'Share invite';

  @override
  String shareInviteText(String name, String code) {
    return 'Join my group “$name” on Splitify Free Forever: code $code';
  }

  @override
  String get resetCode => 'Reset code';

  @override
  String get resetCodeTitle => 'Reset the invite code?';

  @override
  String get resetCodeBody => 'The old code and QR stop working at once.';

  @override
  String get codeResetDone => 'New code ready';

  @override
  String get inviteNoCode =>
      'This group is not on the server yet. Connect to the internet to get its invite code.';

  @override
  String get joinSubtitle => 'Type the invite code or scan the QR a friend shows you.';

  @override
  String get enterCode => 'Enter code';

  @override
  String get scanQr => 'Scan QR';

  @override
  String get inviteCodeLabel => 'Invite code';

  @override
  String get inviteCodeHint => 'ABCD-EFGH';

  @override
  String get findGroup => 'Find group';

  @override
  String get joinInvalidCode => 'That code doesn\'t match any group';

  @override
  String get joinRateLimited => 'Too many tries, wait a bit';

  @override
  String get joinNeedsInternet => 'Joining needs internet';

  @override
  String get joinArchivedNotice => 'This group is archived. You can join, but it is read-only.';

  @override
  String get joinAlreadyMember => 'You\'re already in this group.';

  @override
  String get joinWhoAreYou => 'Are you one of these people?';

  @override
  String get joinWhoAreYouBody => 'Pick your name to keep the expenses already added for you.';

  @override
  String joinAsName(String name) {
    return 'I\'m $name';
  }

  @override
  String get joinNewHere => 'I\'m new here';

  @override
  String joinAsCta(String name) {
    return 'Join as $name';
  }

  @override
  String get openGroup => 'Open group';

  @override
  String get joinOtherCode => 'Use another code';

  @override
  String get joinScanTitle => 'Scan invite QR';

  @override
  String get joinScanHint => 'Point the camera at the invite QR on your friend\'s phone.';

  @override
  String get joinQrInvalid => 'That QR is not a Splitify invite';

  @override
  String joinedGroup(String name) {
    return 'You joined $name';
  }

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
}
