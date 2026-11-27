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
  String notifUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '1 unread',
    );
    return '$_temp0';
  }

  @override
  String get notifAllCaughtUp => 'You\'re all caught up';

  @override
  String get notifMarkAllRead => 'Mark all read';

  @override
  String get notifEmptyTitle => 'No notifications yet';

  @override
  String get notifEmptyBody =>
      'When someone adds an expense with you, pays you or sends a reminder, it shows up here.';

  @override
  String get notifOffline => 'Offline · showing what\'s on this phone';

  @override
  String get notifSettingsTooltip => 'Notification settings';

  @override
  String notifBellLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Notifications, $count unread',
      one: 'Notifications, 1 unread',
      zero: 'Notifications',
    );
    return '$_temp0';
  }

  @override
  String get notifUnread => 'Unread';

  @override
  String get notifKindExpenses => 'Expenses';

  @override
  String get notifKindPayments => 'Payments';

  @override
  String get notifKindReminders => 'Reminders';

  @override
  String get notifKindComments => 'Comments';

  @override
  String get notifKindGroups => 'Groups';

  @override
  String get notifKindExpensesHint => 'Added, edited, deleted or restored';

  @override
  String get notifKindPaymentsHint => 'Payments recorded with you';

  @override
  String get notifKindRemindersHint => 'Someone reminds you to settle up';

  @override
  String get notifKindCommentsHint => 'Comments on expenses you\'re in';

  @override
  String get notifKindGroupsHint => 'People joining or leaving, group settings';

  @override
  String get notifSettingsHint => 'Choose what reaches you, and where.';

  @override
  String get notifSectionPush => 'On your phone';

  @override
  String get notifSectionInApp => 'In the app';

  @override
  String get notifSectionMuted => 'Muted groups';

  @override
  String get notifMutedHint => 'Muted groups still show in the bell, just without pushes.';

  @override
  String get notifMutedOn => 'Muted · bell only';

  @override
  String get notifMutedOff => 'Not muted';

  @override
  String get notifMutedEmpty => 'You\'re not in any groups yet.';

  @override
  String get notifPushOffBuild =>
      'Push notifications aren\'t set up in this build. Everything still shows in the bell.';

  @override
  String get notifPushBlocked =>
      'Notifications are blocked for Splitify on this phone. You\'ll still see everything in the bell.';

  @override
  String get notifPushNotAsked => 'Push notifications are off for now.';

  @override
  String get notifAllow => 'Allow notifications';

  @override
  String get notifRowOn => 'On';

  @override
  String get notifRowBellOnly => 'Bell only';

  @override
  String get notifPrePromptTitle => 'Stay in the loop';

  @override
  String get notifPrePromptBody => 'Get a quiet nudge when something changes in your groups.';

  @override
  String get notifPrePromptPoint1 => 'New expenses you\'re part of';

  @override
  String get notifPrePromptPoint2 => 'Payments and reminders to settle up';

  @override
  String get notifPrePromptPoint3 => 'Comments on your expenses';

  @override
  String get notifPrePromptAllow => 'Turn on notifications';

  @override
  String get notifPrePromptLater => 'Not now';

  @override
  String remindTooltip(String name) {
    return 'Remind $name';
  }

  @override
  String remindSent(String name) {
    return 'Reminder sent to $name';
  }

  @override
  String remindThrottled(String name, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return 'You reminded $name recently. You can remind again in $_temp0.';
  }

  @override
  String remindedTooltip(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return 'Reminded. Again in $_temp0';
  }

  @override
  String remindNothingOwed(String name) {
    return '$name doesn\'t owe you anything here right now.';
  }

  @override
  String get remindNameOnly => 'Only people who joined the app can be reminded.';

  @override
  String get remindFailed => 'Couldn\'t send the reminder. Try again.';

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
  String get welcomeBadge => 'Free forever · no ads';

  @override
  String get getStarted => 'Get started';

  @override
  String get welcomeFooter => 'Open source · made in India';

  @override
  String get welcomeBrand => 'Splitify';

  @override
  String get welcomeSubline =>
      'Split bills with friends, settle up with UPI.\nWorks offline, free forever.';

  @override
  String get welcomeFeatureUpi => 'UPI settle-up';

  @override
  String get welcomeFeatureOffline => 'Works offline';

  @override
  String get welcomeFeatureNoAds => 'No ads ever';

  @override
  String get welcomeInvitePrompt => 'Have an invite?';

  @override
  String get welcomeSampleTrip => 'Goa Trip';

  @override
  String get welcomeSampleHome => 'Flat 4B';

  @override
  String get welcomeSampleAsha => 'Asha';

  @override
  String get welcomeSampleRahul => 'Rahul';

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
    return 'Active groups · $count';
  }

  @override
  String get emptyGroupsTitle => 'Create your first group';

  @override
  String get emptyGroupsBody => 'Trips, flatmates, couples — add the people you split with.';

  @override
  String get archivedGroups => 'Archived groups';

  @override
  String get archivedLabel => 'Archived';

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
  String get groupNameTooLong => 'Use up to 60 characters';

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
  String get groupFormCover => 'Group cover';

  @override
  String get groupFormCoverChoose => 'Choose a photo';

  @override
  String get groupFormPeopleLabel => 'Add people';

  @override
  String get groupFormPeopleHint => 'Type a name, then Add';

  @override
  String get groupFormAddPerson => 'Add';

  @override
  String get groupFormPeopleNote =>
      'They don\'t need the app. They can join later with the invite link and claim their spot.';

  @override
  String groupFormRemovePerson(String name) {
    return 'Remove $name';
  }

  @override
  String get groupFormInvite => 'Invite with a link or QR';

  @override
  String get groupFormInviteNew => 'Saves the group, then shows its link';

  @override
  String get groupFormDiscardTitle => 'Discard this group?';

  @override
  String get groupFormDiscardBody => 'The name and people you typed will be lost.';

  @override
  String get groupFormDiscardEditBody => 'The group stays as it was last saved.';

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
  String get groupBalancesEmptyBody => 'Once the group has expenses, you\'ll see who owes whom.';

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
  String get settingsAddPeople => 'Add people to group';

  @override
  String get settingsInviteLink => 'Invite via link or QR';

  @override
  String get settingsSectionSettings => 'Settings';

  @override
  String get settingsSectionData => 'Data';

  @override
  String settingsGroupCaption(String type, String currency) {
    return '$type · $currency';
  }

  @override
  String get membersSection => 'Members';

  @override
  String get addMember => 'Add member';

  @override
  String get addMemberHint => 'Add someone by name. They can join later and claim this spot.';

  @override
  String get memberNameLabel => 'Name';

  @override
  String get memberNameInvalid => 'Enter a name (up to 50 characters)';

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
      'Everyone loses access. You can restore it for 30 days from Account → Deleted groups.';

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
  String get deletedGroupsBody => 'Groups you deleted. Restore one within 30 days.';

  @override
  String get deletedGroupsEmpty => 'No deleted groups';

  @override
  String get deletedGroupsEmptyBody => 'Groups you delete show up here for 30 days.';

  @override
  String get restore => 'Restore';

  @override
  String restoreDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
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
  String get inviteBody => 'Friends scan this QR, or type the code under Join on the Groups tab.';

  @override
  String inviteQrLabel(String code) {
    return 'QR code for invite code $code';
  }

  @override
  String get copyCode => 'Copy code';

  @override
  String get inviteLinkLabel => 'Invite link';

  @override
  String get copyLink => 'Copy link';

  @override
  String get linkCopied => 'Link copied';

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
  String get joinSubtitle => 'Paste or type the invite code, or scan the QR a friend shows you.';

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
  String get joinRateLimited => 'Too many tries. Wait a minute and try again.';

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
  String get joinPaste => 'Paste';

  @override
  String get joinPasteEmpty => 'There is no invite code to paste';

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
  String get friendsSection => 'Friends';

  @override
  String get friendsSearchHint => 'Search friends';

  @override
  String get addFriendExpense => 'Add friend expense';

  @override
  String friendsNoMatch(String query) {
    return 'No one called “$query”';
  }

  @override
  String get friendOwesYou => 'owes you';

  @override
  String get friendYouOwe => 'you owe';

  @override
  String get friendDirectOnly => 'Friend expenses';

  @override
  String friendGroupsMore(String names, int count) {
    return '$names +$count';
  }

  @override
  String friendPillOwed(String name, String amount) {
    return '$name owes you $amount';
  }

  @override
  String friendPillOwe(String name, String amount) {
    return 'You owe $name $amount';
  }

  @override
  String get friendByGroup => 'By group';

  @override
  String get friendSharedItems => 'Shared expenses';

  @override
  String get friendNoItemsTitle => 'Nothing shared yet';

  @override
  String friendNoItemsBody(String name) {
    return 'Add an expense with $name to get started.';
  }

  @override
  String get friendDirectGroup => 'Just you two';

  @override
  String friendItemCaption(String group, String date) {
    return '$group · $date';
  }

  @override
  String get friendNotFound => 'This friend isn\'t on this phone';

  @override
  String friendSettledSnack(String name) {
    return 'You and $name are settled up';
  }

  @override
  String friendSettleTitle(String name) {
    return 'Settle up with $name';
  }

  @override
  String friendInvite(String name) {
    return 'Invite $name to claim their spot';
  }

  @override
  String friendNeedsInternet(String name) {
    return 'Connect to the internet once to start sharing with $name. After that it works offline.';
  }

  @override
  String friendStartFailed(String name) {
    return 'Couldn\'t start an expense with $name. Try again.';
  }

  @override
  String get friendGroupSettled => 'settled up';

  @override
  String get addFriendWho => 'Who with?';

  @override
  String get addFriendNew => 'Someone new';

  @override
  String get addFriendNewHint => 'They don\'t need the app. Invite them later to claim their spot.';

  @override
  String get addFriend => 'Add friend';

  @override
  String get addFriendTitle => 'Add a friend';

  @override
  String get addFriendInvite => 'Add and invite with a link';

  @override
  String addFriendAdded(String name) {
    return '$name added';
  }

  @override
  String friendRemindPick(String name) {
    return 'Remind $name';
  }

  @override
  String get remindAction => 'Remind';

  @override
  String get addFriendNoFriends => 'No friends yet. Add someone new below.';

  @override
  String get simplifyTitle => 'Simplify debts';

  @override
  String get simplifyHelp =>
      'Fewer payments, same totals. Someone may pay a person they didn\'t share an expense with.';

  @override
  String get simplifyOnDone => 'Simplify debts is on';

  @override
  String get simplifyOffDone => 'Simplify debts is off';

  @override
  String actSimplifyOn(String actor) {
    return '$actor turned on simplify debts';
  }

  @override
  String actSimplifyOff(String actor) {
    return '$actor turned off simplify debts';
  }

  @override
  String actDefaultSplitChanged(String actor) {
    return '$actor changed the default split';
  }

  @override
  String upiPay(String amount) {
    return 'Pay $amount via UPI';
  }

  @override
  String get upiOtherWays => 'Pay from another app';

  @override
  String get upiRecordInstead => 'Record without UPI';

  @override
  String upiPayTo(String name) {
    return 'To $name';
  }

  @override
  String get upiCopyId => 'Copy UPI ID';

  @override
  String get upiCopyAmount => 'Copy amount';

  @override
  String get upiShowQr => 'Show UPI QR';

  @override
  String get upiCopied => 'Copied';

  @override
  String get upiReturnTitle => 'Did the payment go through?';

  @override
  String get upiReturnBody =>
      'Your UPI app doesn\'t tell Splitify. Mark it as paid once the money has left your account.';

  @override
  String get upiMarkPaid => 'Mark as paid';

  @override
  String get upiNotYet => 'Not yet';

  @override
  String get upiNoAppTitle => 'No UPI app found';

  @override
  String upiNoAppBody(String name) {
    return 'Pay $name from any UPI app with the UPI ID or the QR code, then record the payment here.';
  }

  @override
  String upiQrTitle(String name) {
    return 'Scan to pay $name';
  }

  @override
  String upiQrBody(String amount) {
    return 'Scan with a UPI app on another phone. Amount $amount.';
  }

  @override
  String get upiFailedHint =>
      'If your app says the payment failed, copy the UPI ID and amount into it by hand.';

  @override
  String upiNote(String group) {
    return 'Splitify: $group';
  }

  @override
  String upiIdLine(String vpa) {
    return 'UPI ID $vpa';
  }

  @override
  String celebrationSettledWith(String name) {
    return 'You and $name are square.';
  }

  @override
  String get activityHero => 'every rupee,\naccounted for.';

  @override
  String get emptyActivityTitle => 'No activity yet';

  @override
  String get emptyActivityBody => 'Expenses, payments and comments show up here.';

  @override
  String get youLower => 'you';

  @override
  String get someone => 'Someone';

  @override
  String get statusOwedAndOwe => 'Owed and owing';

  @override
  String balPillOwed(String amount) {
    return 'You are owed $amount';
  }

  @override
  String balPillOwe(String amount) {
    return 'You owe $amount';
  }

  @override
  String get balBannerOwed => 'You are owed here';

  @override
  String get balBannerOwe => 'You owe here';

  @override
  String get balBannerMixed => 'You are owed and you owe here';

  @override
  String get balBannerSettled => 'In this group';

  @override
  String get balBannerSettledLine2 => 'You\'re all settled';

  @override
  String get balEveryone => 'Everyone';

  @override
  String get balWhoOwesWhom => 'Who owes whom';

  @override
  String get balSuggestedPayments => 'Suggested payments';

  @override
  String get balShowOriginal => 'Show original debts';

  @override
  String get balShowSimplified => 'Show suggested payments';

  @override
  String get balGetsBack => 'gets back';

  @override
  String get balOwes => 'owes';

  @override
  String get balSettledUp => 'settled up';

  @override
  String balPairOwes(String from, String to) {
    return '$from owes $to';
  }

  @override
  String balYouOwePerson(String name) {
    return 'You owe $name';
  }

  @override
  String get balSettle => 'Settle';

  @override
  String get balEveryoneSettled => 'Everyone is settled up';

  @override
  String balCurrencySection(String code) {
    return '$code balances';
  }

  @override
  String get balLoadError => 'Balances could not be loaded';

  @override
  String get totThisMonth => 'This month';

  @override
  String get totAllTime => 'All time';

  @override
  String get totSpent => 'Total spent';

  @override
  String totExpenseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
    );
    return '$_temp0';
  }

  @override
  String get totYourShare => 'Your share';

  @override
  String get totYouPaid => 'You paid';

  @override
  String get totEachPerson => 'Each person';

  @override
  String totPaidShare(String paid, String share) {
    return 'paid $paid · share $share';
  }

  @override
  String get totEmptyMonthTitle => 'Nothing spent this month';

  @override
  String get totEmptyTitle => 'No spending yet';

  @override
  String get totEmptyBody => 'Add an expense and the totals show up here.';

  @override
  String get totFootnote => 'Payments and loans are not counted as spending.';

  @override
  String get totCharts => 'See charts';

  @override
  String get totExportCsv => 'Export CSV';

  @override
  String get insTitle => 'Insights';

  @override
  String insSpendingIn(String currency) {
    return 'Spending in $currency';
  }

  @override
  String get insModeGroup => 'Group';

  @override
  String get insModeMe => 'Me';

  @override
  String get insModeLabel => 'Show spending of';

  @override
  String get insAllGroups => 'All groups and friends';

  @override
  String get insAllGroupsCaption => 'Your share everywhere';

  @override
  String get insPickGroup => 'Choose a group';

  @override
  String get insPickerCaptionGroup => 'Group';

  @override
  String get insPickerCaptionMe => 'Your share in';

  @override
  String get insPickerHint => 'Change group';

  @override
  String get insArchived => 'Archived';

  @override
  String get insByCategory => 'By category';

  @override
  String get insAllTime => 'All time';

  @override
  String get insByMonth => 'By month';

  @override
  String get insLast12Months => 'Last 12 months';

  @override
  String get insTotalSpent => 'Total spent';

  @override
  String get insYourShare => 'Your share';

  @override
  String insPercent(int percent) {
    return '$percent%';
  }

  @override
  String get insPercentSmall => '<1%';

  @override
  String insAmountShare(String amount, String percent) {
    return '$amount · $percent';
  }

  @override
  String insCategoryOfTotal(String percent) {
    return '$percent of the total';
  }

  @override
  String insDonutLabel(String parts) {
    return 'Spending by category: $parts';
  }

  @override
  String insDonutPart(String name, String amount, String percent) {
    return '$name $amount, $percent';
  }

  @override
  String insMonthBar(String month, String amount) {
    return '$month: $amount';
  }

  @override
  String insYearTotal(String amount) {
    return '12-month total $amount';
  }

  @override
  String get insMonthHint => 'Tap a bar to see that month.';

  @override
  String get insOneMonthHint =>
      'Only one month so far. More bars fill in as you add expenses in other months.';

  @override
  String get insNoRecentMonths => 'Nothing spent in the last 12 months.';

  @override
  String insUnconverted(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count expenses in other currencies are left out. Convert them to $currency on their pages to count them.',
      one:
          '1 expense in another currency is left out. Convert it to $currency on its page to count it.',
    );
    return '$_temp0';
  }

  @override
  String get insEmptyTitle => 'Nothing spent yet';

  @override
  String insEmptyGroupBody(String group) {
    return 'Expenses in $group show up here by category and month.';
  }

  @override
  String get insEmptyMeBody => 'Your share of expenses shows up here by category and month.';

  @override
  String get insNoGroupsTitle => 'No groups yet';

  @override
  String get insNoGroupsBody =>
      'Create or join a group and add expenses to see where the money goes.';

  @override
  String get insConvertTitle => 'Convert to see charts';

  @override
  String insConvertBody(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count expenses are in other currencies. Convert them to $currency on their pages to see them here.',
      one: '1 expense is in another currency. Convert it to $currency on its page to see it here.',
    );
    return '$_temp0';
  }

  @override
  String get insLoadError => 'Charts could not be loaded';

  @override
  String exportSubject(String group) {
    return '$group expenses (Splitify)';
  }

  @override
  String get exportEmpty => 'Nothing to export yet. Add an expense first.';

  @override
  String get exportFailed => 'Couldn\'t export. Try again.';

  @override
  String get settleEditTitle => 'Edit payment';

  @override
  String settlePaidSentence(String from, String to) {
    return '$from paid $to';
  }

  @override
  String get settleSwap => 'Swap who paid';

  @override
  String get settleWhoPaid => 'Who paid?';

  @override
  String get settleWhoReceived => 'Who got the money?';

  @override
  String settleChangePerson(String name) {
    return 'Change $name';
  }

  @override
  String get settleAmount => 'Amount';

  @override
  String settleGaugeOf(String owed) {
    return 'of $owed owed';
  }

  @override
  String settleGaugeAll(String owed) {
    return 'settles all of $owed';
  }

  @override
  String settleGaugeOver(String owed) {
    return 'more than the $owed owed';
  }

  @override
  String get settleGaugeNone => 'Nothing is owed here right now. You can still record it.';

  @override
  String settleUseOwed(String owed) {
    return 'Pay all $owed';
  }

  @override
  String get settleMethod => 'Method';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodUpi => 'UPI';

  @override
  String get methodBank => 'Bank';

  @override
  String get methodOther => 'Other';

  @override
  String get settleDate => 'Date';

  @override
  String get settleNote => 'Note';

  @override
  String get settleNoteHint => 'Optional';

  @override
  String settleNoteTooLong(int max) {
    return 'Use up to $max characters';
  }

  @override
  String get settleRecord => 'Record payment';

  @override
  String get settleSave => 'Save payment';

  @override
  String get settleRecorded => 'Payment recorded';

  @override
  String get settleSaved => 'Payment saved';

  @override
  String get settleNotFoundTitle => 'Nothing to settle here';

  @override
  String get settleNotFoundBody => 'This group or payment is not on this phone.';

  @override
  String get settleSuggested => 'Suggested';

  @override
  String get settleOther => 'Record a different payment';

  @override
  String get settleGroupSettled => 'Everyone in this group is settled up.';

  @override
  String get settleWithTitle => 'Settle up with';

  @override
  String get allSettledSnack => 'You\'re all settled up';

  @override
  String get payTitle => 'Payment';

  @override
  String get payEdit => 'Edit payment';

  @override
  String get payDelete => 'Delete payment';

  @override
  String get payDeleted => 'Payment deleted';

  @override
  String get payNotFoundTitle => 'Payment not found';

  @override
  String get payNotFoundBody => 'It may have been deleted, or it has not reached this phone yet.';

  @override
  String get payMethodLabel => 'Method';

  @override
  String get payNoteLabel => 'Note';

  @override
  String get payDetailsLabel => 'Details';

  @override
  String payRowCaption(String date) {
    return 'Payment · $date';
  }

  @override
  String get payYouPaid => 'you paid';

  @override
  String get payYouReceived => 'you received';

  @override
  String get moneyInLabel => 'In';

  @override
  String get settleRecordTitle => 'Record a payment';

  @override
  String get settleRecordCash => 'Record cash payment';

  @override
  String get settleRecordUpi => 'Record UPI payment';

  @override
  String get settleRecordBank => 'Record bank payment';

  @override
  String get settlePayUpi => 'Pay via UPI';

  @override
  String get settleMethodTitle => 'How was it paid?';

  @override
  String settleToolMethod(String method) {
    return 'Method: $method';
  }

  @override
  String get settleToolNoteAdded => 'Note added';

  @override
  String settleSummaryOwed(String owed) {
    return '$owed owed';
  }

  @override
  String settleSummaryAll(String owed) {
    return 'Settles all of $owed';
  }

  @override
  String settleSummaryPart(String owed) {
    return 'Part of the $owed owed';
  }

  @override
  String settleSummaryLeft(String left) {
    return '$left left after this';
  }

  @override
  String settleSummaryOver(String owed) {
    return 'More than the $owed owed';
  }

  @override
  String settleSummaryExtra(String extra) {
    return '$extra more than owed';
  }

  @override
  String get settleNothingOwed => 'Nothing owed right now';

  @override
  String get settleNothingOwedSub => 'You can still record a payment.';

  @override
  String get settleDiscardTitle => 'Discard this payment?';

  @override
  String get settleDiscardBody => 'The amount and note you typed will be lost.';

  @override
  String get settleDiscardEditBody => 'The payment stays as it was last saved.';

  @override
  String get settlePickHint => 'Pick a balance to settle.';

  @override
  String settlePickYouOwe(String amount) {
    return 'you owe $amount';
  }

  @override
  String settlePickOwesYou(String amount) {
    return 'owes you $amount';
  }

  @override
  String settlePickOwes(String name, String amount) {
    return 'owes $name $amount';
  }

  @override
  String get loanDiscardTitle => 'Discard this loan?';

  @override
  String get loanDiscardBody => 'The amount you typed will be lost.';

  @override
  String get loanDiscardEditBody => 'The loan stays as it was last saved.';

  @override
  String get loanWhoTitle => 'Who lent whom?';

  @override
  String get loanWhoHint => 'Change who lent and who borrowed';

  @override
  String loanPillLent(String name) {
    return 'You lent $name';
  }

  @override
  String loanPillBorrowed(String name) {
    return '$name lent you';
  }

  @override
  String loanPillOthers(String lender, String borrower) {
    return '$lender lent $borrower';
  }

  @override
  String get loanPillNoAmount => 'Type the amount';

  @override
  String loanResultOthers(String borrower, String lender, String amount) {
    return '$borrower will owe $lender $amount';
  }

  @override
  String get actFilterAll => 'All';

  @override
  String get actFilterExpenses => 'Expenses';

  @override
  String get actFilterPayments => 'Payments';

  @override
  String get actFilterComments => 'Comments';

  @override
  String get actFilterGroups => 'Groups';

  @override
  String get actEmptyFilteredTitle => 'Nothing here yet';

  @override
  String get actEmptyFilteredBody => 'Try another filter, or check back after the next change.';

  @override
  String get actTitle => 'Activity';

  @override
  String get actRecent => 'Recent activity';

  @override
  String get actSeeAll => 'See all activity';

  @override
  String actGroupCreated(String actor) {
    return '$actor created the group';
  }

  @override
  String actGroupUpdated(String actor) {
    return '$actor updated the group';
  }

  @override
  String actGroupArchived(String actor) {
    return '$actor archived the group';
  }

  @override
  String actGroupUnarchived(String actor) {
    return '$actor unarchived the group';
  }

  @override
  String actGroupDeleted(String actor) {
    return '$actor deleted the group';
  }

  @override
  String actGroupRestored(String actor) {
    return '$actor restored the group';
  }

  @override
  String actMemberAdded(String actor, String member) {
    return '$actor added $member';
  }

  @override
  String actMemberJoined(String actor) {
    return '$actor joined the group';
  }

  @override
  String actMemberClaimed(String actor, String member) {
    return '$actor joined as $member';
  }

  @override
  String actMemberLeft(String member) {
    return '$member left the group';
  }

  @override
  String actMemberRemoved(String actor, String member) {
    return '$actor removed $member';
  }

  @override
  String actExpenseAdded(String actor, String description) {
    return '$actor added “$description”';
  }

  @override
  String actExpenseEdited(String actor, String description) {
    return '$actor edited “$description”';
  }

  @override
  String actExpenseDeleted(String actor, String description) {
    return '$actor deleted “$description”';
  }

  @override
  String actExpenseRestored(String actor, String description) {
    return '$actor restored “$description”';
  }

  @override
  String actPaymentAdded(String actor, String from, String to) {
    return '$actor recorded a payment from $from to $to';
  }

  @override
  String actPaymentEdited(String actor, String from, String to) {
    return '$actor edited a payment from $from to $to';
  }

  @override
  String actPaymentDeleted(String actor, String from, String to) {
    return '$actor deleted a payment from $from to $to';
  }

  @override
  String actPaymentRestored(String actor, String from, String to) {
    return '$actor restored a payment from $from to $to';
  }

  @override
  String actCommentOn(String actor, String description) {
    return '$actor commented on “$description”';
  }

  @override
  String actCommentAdded(String actor) {
    return '$actor added a comment';
  }

  @override
  String actCommentDeleted(String actor) {
    return '$actor deleted a comment';
  }

  @override
  String actReminderSent(String actor) {
    return '$actor sent a payment reminder';
  }

  @override
  String actSettingsChanged(String actor) {
    return '$actor changed the group settings';
  }

  @override
  String actRecurringCreated(String actor) {
    return '$actor set up a recurring bill';
  }

  @override
  String actRecurringCreatedNamed(String actor, String description) {
    return '$actor set “$description” to repeat';
  }

  @override
  String actRecurringUpdated(String actor) {
    return '$actor changed a recurring bill';
  }

  @override
  String actRecurringUpdatedNamed(String actor, String description) {
    return '$actor changed how “$description” repeats';
  }

  @override
  String actRecurringStopped(String actor) {
    return '$actor stopped a recurring bill';
  }

  @override
  String actRecurringStoppedNamed(String actor, String description) {
    return '$actor stopped repeating “$description”';
  }

  @override
  String actImportCompleted(String actor) {
    return '$actor imported expenses from Splitwise';
  }

  @override
  String actUnknown(String actor) {
    return '$actor made a change';
  }

  @override
  String homeGroupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups',
      one: '1 group',
      zero: 'No groups yet',
    );
    return '$_temp0';
  }

  @override
  String homePeopleOweYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people owe you',
      one: '1 person owes you',
    );
    return '$_temp0';
  }

  @override
  String homeYouOwePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'you owe $count people',
      one: 'you owe 1 person',
    );
    return '$_temp0';
  }

  @override
  String get walletBreakdownTitle => 'Balances by group';

  @override
  String get walletBreakdownEmpty => 'You\'re all settled up in every group.';

  @override
  String get you => 'You';

  @override
  String get yourAccount => 'Your account';

  @override
  String get accountSettings => 'Account settings';

  @override
  String get settingsNoUpi => 'No UPI ID yet';

  @override
  String get settingsEdit => 'Edit';

  @override
  String get walletBrand => 'SPLITIFY';

  @override
  String get overallBalance => 'Overall balance';

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
  String get aboutTitle => 'About';

  @override
  String get aboutHeroTitle => 'split bills,\nfree forever.';

  @override
  String get aboutTagline =>
      'A free, open-source app for splitting costs with friends and flatmates, on trips and at home. No ads, no limits, no paywalls.';

  @override
  String get aboutSectionProject => 'Project';

  @override
  String get aboutSourceCode => 'Source code';

  @override
  String get aboutSourceValue => 'GitHub';

  @override
  String get aboutPrivacy => 'Privacy policy';

  @override
  String get aboutReport => 'Report a problem';

  @override
  String get aboutLicencesRow => 'Open-source licences';

  @override
  String get aboutSectionCredits => 'Credits';

  @override
  String get aboutCreditFonts => 'Instrument Serif and Inter fonts, SIL Open Font License';

  @override
  String get aboutCreditIcons => 'Phosphor icons, MIT licence';

  @override
  String get aboutCreditRates => 'Exchange rates from Frankfurter (European Central Bank data)';

  @override
  String get aboutCopyright => 'MIT licence · © Unizoy';

  @override
  String aboutLinkFailed(String url) {
    return 'Couldn\'t open the link: $url';
  }

  @override
  String get celebrationLead => 'all';

  @override
  String get celebrationHighlight => 'settled';

  @override
  String get syncing => 'Syncing…';

  @override
  String stepDone(String label) {
    return '$label, done';
  }

  @override
  String stepCurrent(String label) {
    return '$label, current step';
  }

  @override
  String get expDescriptionLabel => 'Description';

  @override
  String get expDescriptionHint => 'Dinner, cab, groceries…';

  @override
  String get expDescriptionMissing => 'Add a description';

  @override
  String get expDescriptionTooLong => 'Use up to 120 characters';

  @override
  String get expAddTitle => 'Add expense';

  @override
  String get expWithLabel => 'With you and';

  @override
  String get expWithChoose => 'Choose group or friend';

  @override
  String get expWithChange => 'Change group or friend';

  @override
  String get expWithMissing => 'Choose who this is with';

  @override
  String get expWithChooseFirst => 'Choose a group or friend first';

  @override
  String get expWithPickTitle => 'With you and…';

  @override
  String get expWithSearchHint => 'Search groups and friends';

  @override
  String get expWithRecent => 'Recent';

  @override
  String get expWithGroups => 'Groups and friends';

  @override
  String get expWithFriends => 'More friends';

  @override
  String get expWithFriendLabel => 'Friend';

  @override
  String expWithAddFriend(String name) {
    return 'Add “$name” as a friend';
  }

  @override
  String get expWithAddFriendHint => 'No account needed; they can join later';

  @override
  String get expWithNothingYet => 'No groups or friends yet. Type a name to add a friend.';

  @override
  String get expAmountMissing => 'Enter an amount';

  @override
  String get expPaidSplitTitle => 'Paid by and split';

  @override
  String get expPaidSplitHint => 'Change who paid and how it\'s split';

  @override
  String expPillPaidBy(String name) {
    return 'Paid by $name';
  }

  @override
  String expPillPeoplePaid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people paid',
      one: '1 person paid',
      zero: 'Several people paid',
    );
    return '$_temp0';
  }

  @override
  String expPillSummary(String paid, String how) {
    return '$paid · $how';
  }

  @override
  String get expPillSplitEqual => 'split equally';

  @override
  String get expPillSplitExact => 'split exactly';

  @override
  String get expPillSplitPercent => 'split by percentages';

  @override
  String get expPillSplitShares => 'split by shares';

  @override
  String get expPillSplitAdjust => 'split with adjustments';

  @override
  String get expSplitSectionLabel => 'Split';

  @override
  String get expDiscardTitle => 'Discard this expense?';

  @override
  String get expDiscardBody => 'The amount and details you typed will be lost.';

  @override
  String get expDiscardEditTitle => 'Discard your changes?';

  @override
  String get expDiscardEditBody => 'The expense stays as it was last saved.';

  @override
  String expToolDate(String date) {
    return 'Date: $date';
  }

  @override
  String expToolFirstDate(String date) {
    return 'First date: $date';
  }

  @override
  String get expToolNotesAdded => 'Notes added';

  @override
  String get expToolReceiptAdded => 'Receipt added';

  @override
  String get expCategoryPick => 'Pick a category';

  @override
  String expCurrencyLabel(String code) {
    return 'Currency $code';
  }

  @override
  String get curPickerTitle => 'Currency';

  @override
  String get curSearchLabel => 'Search currencies';

  @override
  String get curSearchHint => 'Code or name';

  @override
  String get curGroupSection => 'Group currency';

  @override
  String get curRecentSection => 'Recent';

  @override
  String get curAllSection => 'All currencies';

  @override
  String curNoMatch(String query) {
    return 'No currency matches “$query”';
  }

  @override
  String curRowLabel(String name, String code) {
    return '$name, $code';
  }

  @override
  String get curSelected => 'selected';

  @override
  String fxConvertTo(String code) {
    return 'Convert to $code';
  }

  @override
  String fxInCurrency(String code) {
    return 'In $code';
  }

  @override
  String fxRateFieldLabel(String from) {
    return 'Rate for 1 $from';
  }

  @override
  String get fxRateNeeded => 'Rate needed';

  @override
  String get fxRateHint => 'e.g. 83.12';

  @override
  String fxRateLine(String from, String rate, String to) {
    return '1 $from = $rate $to';
  }

  @override
  String fxSourceFrankfurter(String date) {
    return 'Frankfurter · $date';
  }

  @override
  String fxSourceFallback(String date, String asked) {
    return 'Frankfurter · $date (latest before $asked)';
  }

  @override
  String fxSourceManual(String date) {
    return 'Rate you typed · $date';
  }

  @override
  String fxNoRateUnlisted(String code) {
    return '$code has no published rate. Type the rate.';
  }

  @override
  String fxNoRateMissing(String date) {
    return 'No saved rate for $date on this phone. Type the rate, or connect to the internet.';
  }

  @override
  String get fxReferenceNote => 'Reference rates from central banks, not your bank\'s rate.';

  @override
  String get fxRateError => 'Enter a rate above 0 with up to 10 decimals';

  @override
  String get fxTooLarge => 'The converted amount is too large';

  @override
  String get fxUseAuto => 'Use Frankfurter rate';

  @override
  String get fxSave => 'Save conversion';

  @override
  String get fxRemove => 'Remove conversion';

  @override
  String get fxSavedSnack => 'Conversion saved';

  @override
  String get fxRemovedSnack => 'Conversion removed';

  @override
  String fxApprox(String amount) {
    return '≈ $amount';
  }

  @override
  String get fxNotPossible => 'This record is already in the group\'s currency.';

  @override
  String get fxViewByCurrency => 'By currency';

  @override
  String fxViewInMain(String code) {
    return 'In $code';
  }

  @override
  String get fxViewLabel => 'Show balances';

  @override
  String fxMissingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records need a rate',
      one: '1 record needs a rate',
    );
    return '$_temp0';
  }

  @override
  String fxMissingBody(String code) {
    return 'Balances in $code use the rate saved with each record, so these need a rate first.';
  }

  @override
  String get fxConvertAll => 'Convert all at each date\'s rate';

  @override
  String fxConvertedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count converted',
      one: '1 converted',
      zero: 'Nothing converted',
    );
    return '$_temp0';
  }

  @override
  String fxNeedRateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need a rate you type',
      one: '1 needs a rate you type',
    );
    return '$_temp0';
  }

  @override
  String get fxConvertedNote => 'Each record is counted at the rate saved with it.';

  @override
  String fxSectionInMain(String code) {
    return 'Everything in $code';
  }

  @override
  String fxSimplifyInMain(String code) {
    return 'Simplify in $code';
  }

  @override
  String get fxCombineError => 'These records can\'t be combined yet. Check their conversions.';

  @override
  String get expAmountLabel => 'Amount';

  @override
  String expAmountErrorDecimals(String currency, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count decimals',
      one: '1 decimal',
      zero: 'no decimals',
    );
    return '$currency allows $_temp0';
  }

  @override
  String get expAmountErrorDivide => 'You can\'t divide by 0';

  @override
  String get expAmountErrorNotPositive => 'Enter an amount above zero';

  @override
  String get expAmountErrorTooLarge => 'That amount is too large';

  @override
  String get expAmountErrorInvalid => 'Check the amount';

  @override
  String get expKeyDelete => 'Delete';

  @override
  String get expKeyPlus => 'Plus';

  @override
  String get expKeyMinus => 'Minus';

  @override
  String get expKeyTimes => 'Times';

  @override
  String get expKeyDivide => 'Divided by';

  @override
  String get expKeyDot => 'Decimal point';

  @override
  String get expSave => 'Save';

  @override
  String get expSaveExpense => 'Save expense';

  @override
  String get expSaved => 'Expense saved';

  @override
  String get expMultiplePeople => 'Multiple people';

  @override
  String get expSplitEqual => 'Equally';

  @override
  String get expSplitExact => 'Exact amounts';

  @override
  String get expSplitPercent => 'Percentages';

  @override
  String get expSplitShares => 'Shares';

  @override
  String get expSplitAdjust => 'Adjustment';

  @override
  String get expSplitEqualHint => 'Everyone ticked pays the same.';

  @override
  String get expSplitExactHint => 'Type what each person owes.';

  @override
  String get expSplitPercentHint => 'Give each person a percentage.';

  @override
  String get expSplitSharesHint => 'Give each person shares, like 2 for a couple.';

  @override
  String get expSplitAdjustHint => 'Add or take away for someone; the rest is split equally.';

  @override
  String get expNotIncluded => 'Not included';

  @override
  String expIncludeMember(String name) {
    return 'Include $name';
  }

  @override
  String expMemberAmountLabel(String name) {
    return 'Amount for $name';
  }

  @override
  String expMemberPercentLabel(String name) {
    return 'Percentage for $name';
  }

  @override
  String expMemberSharesLabel(String name) {
    return 'Shares for $name';
  }

  @override
  String expMemberAdjustLabel(String name) {
    return 'Adjustment for $name';
  }

  @override
  String expFooterEqual(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0 · $amount each';
  }

  @override
  String expFooterPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String expFooterLeft(String sum, String total, String left) {
    return '$sum of $total · $left left';
  }

  @override
  String expFooterOver(String sum, String total, String over) {
    return '$sum of $total · $over over';
  }

  @override
  String expFooterDone(String total) {
    return '$total · done';
  }

  @override
  String expFooterPercentLeft(String sum, String left) {
    return '$sum% of 100% · $left% left';
  }

  @override
  String expFooterPercentOver(String sum, String over) {
    return '$sum% of 100% · $over% over';
  }

  @override
  String get expFooterPercentDone => '100% · done';

  @override
  String expFooterShares(String count) {
    return '$count shares in total';
  }

  @override
  String expFooterAdjust(String rest) {
    return '$rest split equally after adjustments';
  }

  @override
  String get expErrNoParticipants => 'Pick at least one person';

  @override
  String get expErrNoShares => 'Give someone at least one share';

  @override
  String expErrNegativeShare(String name, String zero) {
    return '$name\'s share can\'t go below $zero';
  }

  @override
  String expErrNegativeShareAny(String zero) {
    return 'A share can\'t go below $zero';
  }

  @override
  String get expErrPercentRange => 'Percentages go from 0 to 100';

  @override
  String expErrAdjustOver(String over) {
    return 'Adjustments are $over more than the total';
  }

  @override
  String get expErrInvalidInput => 'Check the numbers you typed';

  @override
  String get expErrNeedAmount => 'Enter the amount first';

  @override
  String get expErrGeneric => 'This split doesn\'t add up yet';

  @override
  String get expCategoryLabel => 'Category';

  @override
  String get expCategoryAuto => 'Auto';

  @override
  String expCategoryHintLabel(String category) {
    return 'Category: $category';
  }

  @override
  String expCategoryAutoLabel(String category) {
    return 'Category: $category, picked from the description';
  }

  @override
  String get expDateLabel => 'Date';

  @override
  String get expNotesLabel => 'Notes';

  @override
  String get expNotesHint => 'Anything worth remembering';

  @override
  String get expNotesTooLong => 'Use up to 1,000 characters';

  @override
  String get expToday => 'Today';

  @override
  String get expYesterday => 'Yesterday';

  @override
  String get expPickDate => 'Pick a date';

  @override
  String get expPrevMonth => 'Previous month';

  @override
  String get expNextMonth => 'Next month';

  @override
  String get expYouLower => 'you';

  @override
  String expOwes(String amount) {
    return 'share $amount';
  }

  @override
  String get expOwesNothing => 'no share';

  @override
  String get expNoExpensesTitle => 'No expenses yet';

  @override
  String get expNoExpensesBody => 'Add the first one. It takes a few seconds.';

  @override
  String get expLoadError => 'Couldn\'t load expenses';

  @override
  String get expLoadErrorBody => 'Your data is safe on this phone. Try again in a moment.';

  @override
  String expPaidCaption(String name, String amount) {
    return '$name paid $amount';
  }

  @override
  String expSeveralPaidCaption(int count, String amount) {
    return '$count people paid $amount';
  }

  @override
  String get expYouLent => 'you lent';

  @override
  String get expYouBorrowed => 'you borrowed';

  @override
  String get expNotInvolved => 'not involved';

  @override
  String get expNoBalance => 'no balance';

  @override
  String get expPaidByLabel => 'Paid by';

  @override
  String expSplitLabel(String kind) {
    return 'Split · $kind';
  }

  @override
  String get expDetailsLabel => 'Details';

  @override
  String expAddedBy(String name, String date) {
    return 'Added by $name on $date';
  }

  @override
  String expAddedOn(String date) {
    return 'Added on $date';
  }

  @override
  String get expEdit => 'Edit expense';

  @override
  String get expDelete => 'Delete expense';

  @override
  String get expDeleted => 'Expense deleted';

  @override
  String get expUndo => 'Undo';

  @override
  String get expHistory => 'Edit history';

  @override
  String get expComments => 'Comments';

  @override
  String expEditedBy(String name, String date) {
    return 'Edited by $name on $date';
  }

  @override
  String expEditedOn(String date) {
    return 'Edited on $date';
  }

  @override
  String get histTitle => 'Edit history';

  @override
  String histPaymentTitle(String from, String to) {
    return '$from paid $to';
  }

  @override
  String histAdded(String name) {
    return '$name added this';
  }

  @override
  String histEdited(String name) {
    return '$name edited this';
  }

  @override
  String histDeleted(String name) {
    return '$name deleted this';
  }

  @override
  String histRestored(String name) {
    return '$name restored this';
  }

  @override
  String histLostChange(String name) {
    return '$name\'s edit';
  }

  @override
  String get histNotApplied => 'Not applied (a newer edit won)';

  @override
  String get histFormerMember => 'A former member';

  @override
  String histWhen(String date, String time) {
    return '$date · $time';
  }

  @override
  String get histFieldDescription => 'Description';

  @override
  String get histFieldAmount => 'Amount';

  @override
  String get histFieldDate => 'Date';

  @override
  String get histFieldCategory => 'Category';

  @override
  String get histFieldPayers => 'Paid by';

  @override
  String get histFieldShares => 'Split';

  @override
  String get histFieldSplitKind => 'Split type';

  @override
  String get histFieldNotes => 'Notes';

  @override
  String get histFieldKind => 'Type';

  @override
  String get histFieldMethod => 'Paid with';

  @override
  String get histFieldFrom => 'From';

  @override
  String get histFieldTo => 'To';

  @override
  String get histSplitDetailsChanged => 'Split details changed';

  @override
  String get histReceiptAdded => 'Receipt added';

  @override
  String get histReceiptRemoved => 'Receipt removed';

  @override
  String get histReceiptReplaced => 'Receipt replaced';

  @override
  String get histNoValue => '—';

  @override
  String get histNoVisibleChange => 'Nothing you can see changed';

  @override
  String get histKindExpense => 'Expense';

  @override
  String get histKindIou => 'Loan';

  @override
  String get histMethodCash => 'Cash';

  @override
  String get histMethodUpi => 'UPI';

  @override
  String get histMethodBank => 'Bank transfer';

  @override
  String get histMethodOther => 'Other';

  @override
  String histChangeA11y(String field, String from, String to) {
    return '$field: $from to $to';
  }

  @override
  String get histPending => 'Your latest change shows here once it\'s synced.';

  @override
  String get histOfflineNote => 'Showing saved history. Connect to see newer changes.';

  @override
  String get histOfflineTitle => 'History needs internet';

  @override
  String get histOfflineBody => 'Connect once to load it. After that it stays on this phone.';

  @override
  String get histEmptyTitle => 'No history yet';

  @override
  String get histEmptyBody => 'Changes show up here once they\'re synced.';

  @override
  String get histRetry => 'Try again';

  @override
  String get histNotFound => 'This item isn\'t on this phone';

  @override
  String get histNotFoundBody => 'It may belong to a group you left.';

  @override
  String get cmtHint => 'Add a comment';

  @override
  String get cmtSend => 'Send comment';

  @override
  String get cmtEmptyTitle => 'No comments yet';

  @override
  String get cmtEmptyBody => 'Start the conversation';

  @override
  String get cmtDelete => 'Delete comment';

  @override
  String get cmtDeleteTitle => 'Delete this comment?';

  @override
  String get cmtDeleteBody => 'It disappears for everyone in the group.';

  @override
  String get cmtDeleted => 'Comment deleted';

  @override
  String cmtTooLong(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maxString = maxNumberFormat.format(max);

    return 'Use up to $maxString characters';
  }

  @override
  String get cmtArchived => 'This group is archived, so comments are read-only.';

  @override
  String cmtA11y(String name, String time, String body) {
    return '$name, $time: $body';
  }

  @override
  String get cmtOptions => 'Comment options';

  @override
  String get delTitle => 'Deleted items';

  @override
  String get delSubtitle =>
      'Expenses and payments deleted in this group. Restoring brings one back for everyone.';

  @override
  String get delEmptyTitle => 'Nothing deleted';

  @override
  String get delEmptyBody => 'Deleted expenses and payments show up here, ready to restore.';

  @override
  String delBy(String name, String date) {
    return 'Deleted by $name · $date';
  }

  @override
  String delOn(String date) {
    return 'Deleted $date';
  }

  @override
  String get delRestored => 'Restored';

  @override
  String get delArchivedNote => 'Unarchive the group to restore items.';

  @override
  String delRestoreA11y(String item) {
    return 'Restore $item';
  }

  @override
  String get expNotFoundTitle => 'This expense isn\'t here';

  @override
  String get expNotFoundBody => 'It may have been deleted on another phone.';

  @override
  String expYouLentAmount(String amount) {
    return 'You lent $amount';
  }

  @override
  String expYouBorrowedAmount(String amount) {
    return 'You borrowed $amount';
  }

  @override
  String get expNotInvolvedLong => 'You\'re not involved';

  @override
  String get expNoBalanceLong => 'You\'re even on this one';

  @override
  String get expDefaultSplitTitle => 'Default split';

  @override
  String expDefaultSplitBody(String group) {
    return 'New expenses in $group start with this split. If the members change, it goes back to equal.';
  }

  @override
  String get expDefaultSplitEqualNote => 'Everyone pays the same share.';

  @override
  String get expDefaultSplitSaved => 'Default split saved';

  @override
  String get catFood => 'Food';

  @override
  String get catGroceries => 'Groceries';

  @override
  String get catTravel => 'Travel';

  @override
  String get catRent => 'Rent';

  @override
  String get catUtilities => 'Utilities';

  @override
  String get catShopping => 'Shopping';

  @override
  String get catEntertainment => 'Entertainment';

  @override
  String get catOther => 'Other';

  @override
  String get catFoodDiningOut => 'Dining out';

  @override
  String get catFoodTakeaway => 'Takeaway';

  @override
  String get catFoodSnacks => 'Snacks';

  @override
  String get catGroceriesGroceries => 'Groceries';

  @override
  String get catGroceriesHousehold => 'Household';

  @override
  String get catTravelFlights => 'Flights';

  @override
  String get catTravelTrainBus => 'Train & bus';

  @override
  String get catTravelCabAuto => 'Cab & auto';

  @override
  String get catTravelFuel => 'Fuel';

  @override
  String get catTravelHotel => 'Hotel';

  @override
  String get catTravelParkingTolls => 'Parking & tolls';

  @override
  String get catRentRent => 'Rent';

  @override
  String get catRentMaintenance => 'Maintenance';

  @override
  String get catUtilitiesElectricity => 'Electricity';

  @override
  String get catUtilitiesWater => 'Water';

  @override
  String get catUtilitiesGas => 'Gas';

  @override
  String get catUtilitiesInternetPhone => 'Internet & phone';

  @override
  String get catUtilitiesSubscriptions => 'Subscriptions';

  @override
  String get catShoppingClothing => 'Clothing';

  @override
  String get catShoppingElectronics => 'Electronics';

  @override
  String get catShoppingGifts => 'Gifts';

  @override
  String get catShoppingOther => 'Other shopping';

  @override
  String get catEntertainmentMovies => 'Movies';

  @override
  String get catEntertainmentEvents => 'Events';

  @override
  String get catEntertainmentGames => 'Games';

  @override
  String get catEntertainmentSports => 'Sports';

  @override
  String get catOtherGeneral => 'General';

  @override
  String get catOtherMedical => 'Medical';

  @override
  String get catOtherEducation => 'Education';

  @override
  String get catOtherServices => 'Services';

  @override
  String get signInTitle => 'How would you like to sign in?';

  @override
  String get signInSubtitle =>
      'Use Google or a one-time code sent by email. The same email always opens the same account.';

  @override
  String get signInToJoin => 'Sign in with Google or an email code, then we open your invite.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get googleSoon => 'Google sign-in isn\'t set up in this build. Use your email instead.';

  @override
  String get googleNotSetUp => 'Not set up in this build';

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
  String codeTitle(int digits) {
    return 'Enter the $digits-digit code';
  }

  @override
  String codeSentTo(String email) {
    return 'We sent it to $email. It works for 10 minutes.';
  }

  @override
  String codeBoxes(int count, int digits) {
    return '$digits-digit code, $count of $digits entered';
  }

  @override
  String resendIn(int seconds) {
    return 'Resend code in $seconds s';
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
  String get profileAddUpi => 'Add a UPI ID (optional)';

  @override
  String get profilePhotoTooltip => 'Change your photo';

  @override
  String get continueLabel => 'Continue';

  @override
  String get authErrorInvalidCode =>
      'That code is wrong or has expired. Check your newest email, or tap Resend code.';

  @override
  String get authErrorExpiredCode => 'This code has expired or is not right. Request a new code.';

  @override
  String get authErrorTooManyTries => 'Too many tries. Request a new code.';

  @override
  String get authErrorInvalidEmail => 'Enter an email like name@example.com';

  @override
  String get authErrorOffline => 'You\'re offline. Connect to the internet to sign in.';

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
  String get nameInvalid => 'Enter your name (up to 50 characters)';

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
  String get typeDeleteLabel => 'Type “DELETE” to confirm';

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
  String get syncStateError => 'Sync didn\'t finish. Splitify will try again soon.';

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
      'recurring': 'Repeating expense',
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
  String syncSuperseded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Newer edits by others were kept for $count changes. Your versions are in the edit history.',
      one: 'Someone else\'s newer edit was kept. Your version is in the edit history.',
    );
    return '$_temp0';
  }

  @override
  String expShowOlder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count older',
      one: 'Show 1 older',
    );
    return '$_temp0';
  }

  @override
  String get syncIssueOpen => 'Edit';

  @override
  String get syncUploadsTitle => 'Photos';

  @override
  String syncUploadKind(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'receipt': 'Receipt photo',
      'cover': 'Group cover',
      'other': 'Photo',
    });
    return '$_temp0';
  }

  @override
  String get syncUploadWaiting => 'Waiting to upload';

  @override
  String syncUploadRetrying(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Upload failed $count times, trying again',
      one: 'Upload failed once, trying again',
    );
    return '$_temp0';
  }

  @override
  String syncUploadSkipped(int count) {
    return 'Upload stopped after $count tries';
  }

  @override
  String syncUploadsWaiting(int count) {
    return '$count waiting';
  }

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

  @override
  String get payersMultipleHint =>
      'Type what each person paid. Payers don\'t have to be in the split.';

  @override
  String get payersNone => 'Type at least one amount';

  @override
  String payersDone(String total) {
    return '$total covered';
  }

  @override
  String payerAmountLabel(String name) {
    return 'Amount $name paid';
  }

  @override
  String payersTwo(String first, String second) {
    return '$first and $second';
  }

  @override
  String payersCaption(String names, String amount) {
    return '$names paid $amount';
  }

  @override
  String get loanAction => 'Record a loan';

  @override
  String get loanTitle => 'Record a loan';

  @override
  String get loanEditTitle => 'Edit loan';

  @override
  String get loanSubtitle =>
      'Money lent or borrowed, outside any bill. It isn\'t counted as spending.';

  @override
  String get loanILent => 'I lent';

  @override
  String get loanIBorrowed => 'I borrowed';

  @override
  String get loanToWhom => 'To whom?';

  @override
  String get loanFromWhom => 'From whom?';

  @override
  String loanSentenceLent(String name, String amount) {
    return 'You lent $name $amount';
  }

  @override
  String loanSentenceBorrowed(String name, String amount) {
    return '$name lent you $amount';
  }

  @override
  String loanResultLent(String name, String amount) {
    return '$name will owe you $amount';
  }

  @override
  String loanResultBorrowed(String name, String amount) {
    return 'You will owe $name $amount';
  }

  @override
  String get loanPickPerson => 'Choose a person';

  @override
  String get loanNoOthers => 'Add someone to this group first.';

  @override
  String get loanWhatFor => 'What for?';

  @override
  String get loanWhatForHint => 'Optional, e.g. Cab money';

  @override
  String get loanDefaultDescription => 'Loan';

  @override
  String get loanSave => 'Save loan';

  @override
  String get loanSaved => 'Loan saved';

  @override
  String get loanChip => 'Loan';

  @override
  String loanCaption(String lender, String borrower, String amount) {
    return '$lender lent $borrower $amount';
  }

  @override
  String get loanLentBy => 'Lent by';

  @override
  String get loanBorrowedBy => 'Borrowed by';

  @override
  String get loanAmountLabel => 'Loan amount';

  @override
  String get loanNotSpending => 'Loans aren\'t counted in group totals.';

  @override
  String get receiptLabel => 'Receipt';

  @override
  String get receiptAdd => 'Add receipt photo';

  @override
  String get receiptAddHint => 'One photo per expense, shrunk before it\'s uploaded.';

  @override
  String get receiptPhoto => 'Receipt photo';

  @override
  String get receiptRemoveTitle => 'Remove the receipt photo?';

  @override
  String get receiptRemoveBody =>
      'Everyone in the group stops seeing it. Earlier versions stay in the edit history.';

  @override
  String get receiptRemoved => 'Receipt photo removed';

  @override
  String get receiptReplaced => 'Receipt photo replaced';

  @override
  String get receiptOnList => 'Has a receipt photo';

  @override
  String get photoSourceTitle => 'Add a photo';

  @override
  String get photoTake => 'Take a photo';

  @override
  String get photoChoose => 'Choose from your photos';

  @override
  String get photoChooseHint =>
      'Opens the Android photo picker. Splitify only sees the photo you pick.';

  @override
  String get photoReplace => 'Replace';

  @override
  String get photoRemove => 'Remove';

  @override
  String get photoView => 'Open photo';

  @override
  String get photoClose => 'Close photo';

  @override
  String get photoWaiting => 'Uploads when you\'re online';

  @override
  String get photoOffline => 'Shows when you\'re online';

  @override
  String get photoUnavailable => 'Photo not available';

  @override
  String get photoPickFailed => 'Couldn\'t use that photo. Try another one.';

  @override
  String get photoZoomHint => 'Pinch or double-tap to zoom';

  @override
  String get coverLabel => 'Cover';

  @override
  String get coverGenerated => 'Generated';

  @override
  String get coverPhotoOption => 'Photo';

  @override
  String get coverChangePhoto => 'Change photo';

  @override
  String get coverPhotoHint => 'Your photo is shrunk and shared with group members only.';

  @override
  String get coverPhotoSaved => 'Cover photo saved';

  @override
  String loanNameLent(String name) {
    return '$name lent';
  }

  @override
  String loanNameBorrowed(String name) {
    return '$name borrowed';
  }

  @override
  String get loanAmountDone => 'Done';

  @override
  String get repeatLabel => 'Repeat';

  @override
  String get repeatNever => 'Never';

  @override
  String get repeatWeekly => 'Every week';

  @override
  String get repeatFortnightly => 'Every 2 weeks';

  @override
  String get repeatMonthly => 'Every month';

  @override
  String get repeatYearly => 'Every year';

  @override
  String get repeatEndsLabel => 'Ends';

  @override
  String get repeatNoEnd => 'No end date';

  @override
  String repeatUntil(String date) {
    return 'Until $date';
  }

  @override
  String get repeatPickEnd => 'Pick an end date';

  @override
  String repeatEndBeforeStart(String date) {
    return 'The end date can\'t be before $date';
  }

  @override
  String repeatNextHint(String date) {
    return 'A copy is added automatically on each date. First copy: $date.';
  }

  @override
  String get repeatNoCopiesHint => 'No copies: the end date is before the first one.';

  @override
  String get recurringChip => 'Repeats';

  @override
  String get recurringRowLabel => 'Repeats';

  @override
  String recurringNext(String date) {
    return 'Next copy on $date';
  }

  @override
  String recurringEndsOn(String date) {
    return 'Ends on $date';
  }

  @override
  String get recurringNoEnd => 'No end date';

  @override
  String get recurringFinished => 'No more copies';

  @override
  String get recurringStoppedValue => 'Stopped';

  @override
  String get recurringStoppedLine => 'Stopped repeating. Copies already added stay.';

  @override
  String get recurringCopyLine => 'Added automatically from a repeating expense';

  @override
  String get recurringEditFuture => 'Edit future copies';

  @override
  String get recurringStop => 'Stop repeating';

  @override
  String recurringStopTitle(String description) {
    return 'Stop repeating “$description”?';
  }

  @override
  String get recurringStopBody =>
      'No more copies will be added. Copies already added stay as they are.';

  @override
  String get recurringStopKeep => 'Keep repeating';

  @override
  String get recurringStoppedSnack => 'Stopped repeating';

  @override
  String get recurringResume => 'Repeat again';

  @override
  String get recurringResumedSnack => 'Repeats again from today';

  @override
  String recurringEditPill(String group) {
    return 'Future copies · $group';
  }

  @override
  String get recurringEditNote =>
      'Changes apply to copies added from now on. Copies already added stay as they are.';

  @override
  String get recurringSaved => 'Future copies updated';

  @override
  String get recurringNotFoundTitle => 'Not on this phone';

  @override
  String get recurringNotFoundBody => 'This repeating expense isn\'t on this phone any more.';

  @override
  String get recurringDeleteAlsoStops => 'Deleted. It won\'t repeat any more.';

  @override
  String actRecurringCopy(String description) {
    return '“$description” was added (repeats)';
  }

  @override
  String actRecurringStoppedAuto(String description) {
    return '“$description” stopped repeating';
  }

  @override
  String get searchTooltip => 'Search expenses';

  @override
  String get searchFieldHint => 'Search expenses';

  @override
  String get searchClear => 'Clear search';

  @override
  String get searchFilterGroup => 'Group';

  @override
  String get searchFilterPerson => 'Person';

  @override
  String get searchFilterDate => 'Date';

  @override
  String get searchFilterCategory => 'Category';

  @override
  String get searchAnyGroup => 'All groups';

  @override
  String get searchAnyPerson => 'Anyone';

  @override
  String get searchAnyDate => 'Any time';

  @override
  String get searchAnyCategory => 'All categories';

  @override
  String get searchThisMonth => 'This month';

  @override
  String get searchLastMonth => 'Last month';

  @override
  String get searchLast3Months => 'Last 3 months';

  @override
  String get searchThisYear => 'This year';

  @override
  String get searchPickDates => 'Pick dates';

  @override
  String get searchFromTitle => 'From';

  @override
  String get searchToTitle => 'To';

  @override
  String searchDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get searchStartTitle => 'Find any expense';

  @override
  String get searchStartBody =>
      'Search by description, note, person or amount. It works offline too.';

  @override
  String get searchNoResultsTitle => 'No matches';

  @override
  String get searchNoResultsBody => 'Try another word, or remove a filter.';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
    );
    return '$_temp0';
  }

  @override
  String searchLimited(int count) {
    return 'Showing the newest $count';
  }

  @override
  String get searchClearFilters => 'Clear filters';

  @override
  String get searchNoPeople => 'No people yet';

  @override
  String get impTitle => 'Import from Splitwise';

  @override
  String get impStepFile => 'File';

  @override
  String get impStepGroup => 'Group';

  @override
  String get impStepPeople => 'People';

  @override
  String get impStepPreview => 'Preview';

  @override
  String get impStepDone => 'Done';

  @override
  String get impFileQuestion => 'Bring a Splitwise group over';

  @override
  String get impHow1 =>
      'In Splitwise, open the group, tap the settings gear, then Export as spreadsheet.';

  @override
  String get impHow2 => 'Save the CSV file on this phone, then choose it here.';

  @override
  String get impHow3 => 'Files exported from Splitify work too.';

  @override
  String get impChooseFile => 'Choose CSV file';

  @override
  String get impIntoGroup => 'Import into';

  @override
  String impFileRows(int count, String currencies) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0 · $currencies';
  }

  @override
  String get impChangeFile => 'Change';

  @override
  String get impPreviewButton => 'Preview import';

  @override
  String get impChooseAnother => 'Choose another file';

  @override
  String get impErrTitle => 'Can\'t read this file';

  @override
  String get impErrEmpty => 'This file is empty.';

  @override
  String get impErrHeader =>
      'This doesn\'t look like a Splitwise or Splitify export. Its first row should start with Date, Description, Category.';

  @override
  String impErrColumns(int row) {
    return 'Row $row has a different number of cells than the first row.';
  }

  @override
  String impErrDate(int row, String value) {
    return 'Row $row: “$value” is not a date (YYYY-MM-DD).';
  }

  @override
  String impErrCurrency(int row, String value) {
    return 'Row $row: “$value” is not a currency code.';
  }

  @override
  String impErrAmount(int row, String value) {
    return 'Row $row: “$value” is not an amount.';
  }

  @override
  String impErrUnbalanced(int row) {
    return 'Row $row doesn\'t add up: someone\'s share is missing.';
  }

  @override
  String impErrDuplicateTotals(int row, String value) {
    return 'Row $row repeats the Total balance row for $value.';
  }

  @override
  String get impErrTooLarge => 'This file is larger than 5 MB.';

  @override
  String get impErrNoRows => 'There are no expenses or payments in this file.';

  @override
  String impErrUnsupported(String code) {
    return 'Splitify can\'t handle $code amounts yet.';
  }

  @override
  String get impEarlier => 'Imported on this phone';

  @override
  String impBatchTitle(String file) {
    return '$file';
  }

  @override
  String impBatchWhen(String date) {
    return 'Imported $date';
  }

  @override
  String get impGroupQuestion => 'Where should it go?';

  @override
  String get impNewGroup => 'New group';

  @override
  String get impGroupName => 'Group name';

  @override
  String get impGroupNameHint => 'Goa trip';

  @override
  String get impYourGroups => 'Your groups';

  @override
  String get impContinue => 'Continue';

  @override
  String get impPeopleQuestion => 'Who is who?';

  @override
  String impPeopleHint(String group) {
    return 'Match each person in the file to someone in “$group”.';
  }

  @override
  String get impPeopleHintNew =>
      'Match each person in the file. Everyone except you joins as a name-only member.';

  @override
  String get impChoiceNew => 'New person';

  @override
  String get impChoiceSkip => 'Skipped';

  @override
  String impPickFor(String name) {
    return 'Who is $name?';
  }

  @override
  String impAddNew(String name) {
    return 'Add “$name” as a new person';
  }

  @override
  String impSkip(String name) {
    return 'Skip $name';
  }

  @override
  String get impSkipBody => 'Rows that involve them are left out.';

  @override
  String impNetPlus(String amount) {
    return 'gets back $amount';
  }

  @override
  String impNetMinus(String amount) {
    return 'owes $amount';
  }

  @override
  String get impNetZero => 'settled up';

  @override
  String get impProblemSameMember => 'Two people in the file are matched to the same member.';

  @override
  String get impProblemEmptyName => 'A new person needs a name.';

  @override
  String get impProblemNobody => 'Choose at least one person to import.';

  @override
  String get impProblemTooMany => 'A group can have up to 100 members.';

  @override
  String get impPreviewQuestion => 'Check before importing';

  @override
  String impCountExpenses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
    );
    return '$_temp0';
  }

  @override
  String impCountPayments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments',
      one: '1 payment',
    );
    return '$_temp0';
  }

  @override
  String impDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String impStatExpenses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expenses',
      one: 'Expense',
    );
    return '$_temp0';
  }

  @override
  String impStatPayments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Payments',
      one: 'Payment',
    );
    return '$_temp0';
  }

  @override
  String impStatPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'People',
      one: 'Person',
    );
    return '$_temp0';
  }

  @override
  String get impTotalsTitle => 'Total balance check';

  @override
  String get impTotalsOk => 'Matches the file';

  @override
  String get impTotalsNone => 'No Total balance row to check against';

  @override
  String get impTotalsMismatch => 'Doesn\'t match the file';

  @override
  String impMismatchRow(String name, String file, String rows) {
    return '$name: the file says $file, its rows add up to $rows';
  }

  @override
  String get impImportAnyway => 'Import anyway';

  @override
  String get impImportAnywaySub => 'Balances follow the rows, not the Total balance row.';

  @override
  String impDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows involve people you skipped and are left out.',
      one: '1 row involves someone you skipped and is left out.',
    );
    return '$_temp0';
  }

  @override
  String impZeroRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows change nobody\'s balance and are left out.',
      one: '1 row changes nobody\'s balance and is left out.',
    );
    return '$_temp0';
  }

  @override
  String impNetsRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count expenses with several payers come in as net amounts; their original cost goes in the notes.',
      one: '1 expense with several payers comes in as net amounts; its original cost goes in the notes.',
    );
    return '$_temp0';
  }

  @override
  String get impBalancesAfter => 'Balances from this file';

  @override
  String impImportButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count records',
      one: 'Import 1 record',
    );
    return '$_temp0';
  }

  @override
  String get impRunning => 'Importing…';

  @override
  String impRunningCount(int done, int total) {
    return '$done of $total';
  }

  @override
  String get impDoneLead => 'all';

  @override
  String get impDoneHighlight => 'imported';

  @override
  String impDoneBody(String expenses, String payments, String group) {
    return '$expenses and $payments are in “$group”.';
  }

  @override
  String get impOpenGroup => 'Open group';

  @override
  String get impDeleteImport => 'Delete this import';

  @override
  String get impDeleteTitle => 'Delete this import?';

  @override
  String get impDeleteBody =>
      'Every expense and payment from this file is deleted. You can bring them back one by one from Deleted items.';

  @override
  String get impDeleted => 'Import deleted';

  @override
  String get impDeletedBody =>
      'The records from this file are deleted. People added for the import stay in the group.';

  @override
  String get impFallbackDescription => 'Imported expense';

  @override
  String actImportCompletedFile(String actor) {
    return '$actor imported expenses from a Splitify file';
  }

  @override
  String actImportUndone(String actor) {
    return '$actor deleted an import';
  }

  @override
  String actImportCounts(String expenses, String payments) {
    return '$expenses · $payments';
  }

  @override
  String get lockSecurity => 'Security';

  @override
  String get lockSecuritySubtitle => 'App lock';

  @override
  String get lockAppLock => 'App lock';

  @override
  String get lockAppLockSub => 'Ask for your fingerprint or screen lock to open Splitify.';

  @override
  String get lockAfter => 'Lock after';

  @override
  String lockMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String lockMinutesShort(int count) {
    return '$count min';
  }

  @override
  String get lockAfterSub =>
      'Splitify locks after this long in the background, and always when it starts.';

  @override
  String get lockRecentsNote =>
      'While app lock is on, the preview of Splitify in recent apps is hidden.';

  @override
  String get lockNeedsScreenLock =>
      'Set a screen lock (PIN, pattern, password or fingerprint) on this phone first.';

  @override
  String get lockReason => 'Unlock Splitify';

  @override
  String get lockTitle => 'Splitify is locked';

  @override
  String get lockBody => 'Use your fingerprint or screen lock to see your groups and balances.';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get lockOn => 'On';

  @override
  String get lockOff => 'Off';

  @override
  String get lockConfirmFailed => 'Couldn\'t confirm it\'s you. Try again.';

  @override
  String get lockTurnedOff => 'This phone has no screen lock any more, so app lock is off.';

  @override
  String get widgetRow => 'Home screen widget';

  @override
  String get widgetTitle => 'Home screen widget';

  @override
  String get widgetHowTo =>
      'Long-press your home screen, tap Widgets and pick Splitify. It shows your overall balance and opens the app when tapped.';

  @override
  String get widgetHideAmounts => 'Hide amounts';

  @override
  String get widgetHideAmountsSub =>
      'The widget shows whether you owe or are owed, without numbers.';

  @override
  String widgetUpdated(String time) {
    return 'Updated $time';
  }

  @override
  String get widgetUpdatedNow => 'Updated just now';

  @override
  String get widgetNotSynced => 'Not synced yet';

  @override
  String get widgetSignedOut => 'Open Splitify to sign in';

  @override
  String get widgetHidden => 'Amounts hidden';

  @override
  String get widgetBrand => 'Splitify';

  @override
  String get linkNotFoundTitle => 'This link doesn\'t open anything';

  @override
  String get linkNotFoundBody => 'It may be old or mistyped. Your groups are one tap away.';

  @override
  String get linkNotFoundAction => 'Go to groups';

  @override
  String get balYouGetBack => 'get back';

  @override
  String get balYouOwe => 'owe';

  @override
  String syncStatePhotosStopped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos stopped uploading',
      one: '1 photo stopped uploading',
    );
    return '$_temp0';
  }

  @override
  String get syncStatePhotosStoppedHint => 'Tap Retry under Photos below.';

  @override
  String syncStatePhotosWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos waiting to upload',
      one: '1 photo waiting to upload',
    );
    return '$_temp0';
  }

  @override
  String syncRowPhotosStopped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos stopped',
      one: '1 photo stopped',
    );
    return '$_temp0';
  }

  @override
  String get notifOpenSettings => 'Open phone settings';

  @override
  String get backupRow => 'Your data';

  @override
  String get backupRowValue => 'Download';

  @override
  String get backupTitle => 'Your data';

  @override
  String get backupBody =>
      'Everything on this phone in one .zip: a full backup (JSON) and a spreadsheet (CSV) for each group. It is made on your phone, so it works offline.';

  @override
  String backupGroups(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString groups',
      one: '1 group',
    );
    return '$_temp0';
  }

  @override
  String backupExpenses(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString expenses',
      one: '1 expense',
    );
    return '$_temp0';
  }

  @override
  String backupPayments(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString payments',
      one: '1 payment',
    );
    return '$_temp0';
  }

  @override
  String backupPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes are not synced yet. They are in the file, marked as pending.',
      one: '1 change is not synced yet. It is in the file, marked as pending.',
    );
    return '$_temp0';
  }

  @override
  String get backupDownload => 'Download my data';

  @override
  String get backupShare => 'Share instead';

  @override
  String get backupWorking => 'Preparing your file…';

  @override
  String backupSaved(String file) {
    return 'Saved $file';
  }

  @override
  String get backupFailed => 'The file could not be made. Try again.';

  @override
  String get backupEmpty => 'Nothing to download yet. Create a group first.';

  @override
  String get backupSubject => 'My Splitify data';

  @override
  String get backupFormatNote =>
      'Amounts are whole paise (or cents) with their currency code, so nothing is rounded.';

  @override
  String get search2FieldHint => 'Search everything';

  @override
  String search2HintIn(String group) {
    return 'Search in $group';
  }

  @override
  String get search2StartTitle => 'Find anything';

  @override
  String get search2StartBody =>
      'Expenses, payments and comments, by description, note, person or amount. It works offline too.';

  @override
  String search2StartBodyIn(String group) {
    return 'Expenses, payments and comments in $group, by description, note, person or amount.';
  }

  @override
  String get search2KindAll => 'All';

  @override
  String get search2KindExpenses => 'Expenses';

  @override
  String get search2KindPayments => 'Payments';

  @override
  String get search2KindComments => 'Comments';

  @override
  String search2KindChip(String label, int count) {
    return '$label · $count';
  }

  @override
  String get search2KindLabel => 'Result type';

  @override
  String search2ResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String search2ResultCountIn(int count, String group) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results in $group',
      one: '1 result in $group',
    );
    return '$_temp0';
  }

  @override
  String get search2Recent => 'Recent searches';

  @override
  String get search2RecentClear => 'Clear';

  @override
  String get search2RecentClearHint => 'Clear recent searches';

  @override
  String search2RecentRemove(String text) {
    return 'Remove $text';
  }

  @override
  String get search2RecentHint => 'Search again';

  @override
  String search2PaymentCaption(String date, String group) {
    return 'Payment · $date · $group';
  }

  @override
  String search2CommentTitle(String body) {
    return '“$body”';
  }

  @override
  String search2CommentCaption(String author, String target, String date) {
    return '$author on $target · $date';
  }

  @override
  String search2CommentCaptionIn(String author, String target, String date, String group) {
    return '$author on $target · $date · $group';
  }

  @override
  String get search2CommentTargetPayment => 'a payment';

  @override
  String get search2Comment => 'comment';

  @override
  String get trendMonthTab => 'Month';

  @override
  String get trendPrevMonth => 'Previous month';

  @override
  String get trendNextMonth => 'Next month';

  @override
  String trendEmptyMonth(String month) {
    return 'Nothing spent in $month';
  }

  @override
  String get trendCategoryTitle => 'Category over time';

  @override
  String trendCategoryTotal(String amount, String category) {
    return '$amount on $category in the last 12 months';
  }

  @override
  String get trendPickCategory => 'Category';

  @override
  String get trendWhoPaidTitle => 'Who paid';

  @override
  String get trendPickPerson => 'Person';

  @override
  String get trendPaid => 'Paid';

  @override
  String get trendShare => 'Share';

  @override
  String get trendWhoPaidHint => 'What each person paid against their share, month by month.';

  @override
  String trendMemberBar(String month, String paid, String share) {
    return '$month: paid $paid, share $share';
  }

  @override
  String trendMemberTotal(String paid, String share) {
    return 'Last 12 months: paid $paid · share $share';
  }

  @override
  String get entryAnswerYouPaidEqual => 'You paid, split equally';

  @override
  String get entryAnswerYouOwedFull => 'You are owed the full amount';

  @override
  String entryAnswerTheyPaidEqual(String name) {
    return '$name paid, split equally';
  }

  @override
  String entryAnswerTheyOwedFull(String name) {
    return '$name is owed the full amount';
  }

  @override
  String entryAnswerOwesYou(String name, String amount) {
    return '$name owes you $amount';
  }

  @override
  String entryAnswerYouOwe(String name, String amount) {
    return 'You owe $name $amount';
  }

  @override
  String entryAnswerOwesYouHalf(String name) {
    return '$name owes you half';
  }

  @override
  String entryAnswerOwesYouAll(String name) {
    return '$name owes you all of it';
  }

  @override
  String entryAnswerYouOweHalf(String name) {
    return 'You owe $name half';
  }

  @override
  String entryAnswerYouOweAll(String name) {
    return 'You owe $name all of it';
  }

  @override
  String get entryMoreOptions => 'More options';

  @override
  String get entryMoreOptionsHint => 'Several payers, exact amounts, %, shares or items';

  @override
  String entryPillTheyOweFull(String name) {
    return '$name owes the full amount';
  }

  @override
  String get entryPillYouOweFull => 'you owe the full amount';

  @override
  String get entrySplitItems => 'By items';

  @override
  String get entrySplitItemsHint => 'each line goes to the people who had it';

  @override
  String get entryPillSplitItems => 'split by items';

  @override
  String get entryItemHint => 'Item';

  @override
  String entryItemNameLabel(int number) {
    return 'Name of item $number';
  }

  @override
  String entryItemAmountLabel(int number) {
    return 'Price of item $number';
  }

  @override
  String entryItemPersonLabel(String name, int number) {
    return '$name had item $number';
  }

  @override
  String entryItemRemove(int number) {
    return 'Remove item $number';
  }

  @override
  String get entryItemAdd => 'Add item';

  @override
  String get entryItemsExtras => 'Tax, service, tip, discount';

  @override
  String get entryItemsExtrasHint => 'Shared in proportion to what each person had.';

  @override
  String get entryExtraTax => 'Tax (GST)';

  @override
  String get entryExtraService => 'Service charge';

  @override
  String get entryExtraTip => 'Tip';

  @override
  String get entryExtraDiscount => 'Discount';

  @override
  String get entryItemsEach => 'Each person';

  @override
  String entryItemsUseTotal(String amount) {
    return 'Use items total · $amount';
  }

  @override
  String get entryItemsNoPeople => 'Every item needs at least one person';

  @override
  String get entryItemsNone => 'Add an item with a price';

  @override
  String get entryItemsTooMany => 'Too many items to save. Join a few lines.';

  @override
  String get entryItemsDiscountTooBig => 'The discount is bigger than the items';

  @override
  String get entryScanReceipt => 'Scan receipt';

  @override
  String get entryScanReceiptHint => 'Fills in the amount, date and items. Works offline.';

  @override
  String get entryScanReading => 'Reading the receipt…';

  @override
  String get entryScanTitle => 'From your receipt';

  @override
  String get entryScanAmount => 'Amount';

  @override
  String get entryScanDate => 'Date';

  @override
  String get entryScanDescription => 'Description';

  @override
  String entryScanItemsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items found',
      one: '1 item found',
    );
    return '$_temp0';
  }

  @override
  String entryScanReplaces(String value) {
    return 'Replaces $value';
  }

  @override
  String get entryScanUse => 'Use these';

  @override
  String get entryScanItemize => 'Split by items';

  @override
  String get entryScanItemizeNeedsGroup => 'Choose who it\'s with first to split by items.';

  @override
  String get entryScanNothingTitle => 'Couldn\'t read this receipt';

  @override
  String get entryScanNothingBody =>
      'The photo is attached. Try a sharper photo in good light, or type the amount.';

  @override
  String get entryScanKeepPhoto => 'Keep the photo';

  @override
  String get entryScanRetry => 'Try another photo';

  @override
  String get entryScanFailed => 'Couldn\'t read that photo. Try another one.';

  @override
  String get entryScanPhotoNote =>
      'The photo is attached as the receipt and uploads when you\'re online.';

  @override
  String entryScanTickLabel(String field, String value) {
    return 'Use $field: $value';
  }

  @override
  String get entryDeletedPill => 'Deleted';

  @override
  String get entryDeletedNote =>
      'This expense was deleted. It doesn\'t count in balances until it is restored.';

  @override
  String get entryRestore => 'Restore';

  @override
  String get entryRestoreExpense => 'Restore expense';

  @override
  String get entryRestored => 'Expense restored';

  @override
  String entryTrendTitle(String category, String group) {
    return '$category in $group';
  }

  @override
  String get entryTrendSubtitle => 'Last 3 months';

  @override
  String get entryTrendOpen => 'Open insights';

  @override
  String entryTrendMonth(String month, String amount) {
    return '$month: $amount';
  }

  @override
  String get entryShareNothing => 'Nothing to add from what was shared.';

  @override
  String get entryItemsLabel => 'Items';

  @override
  String entryItemsComesTo(String amount) {
    return 'Items come to $amount';
  }

  @override
  String groupLinesMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+1 more',
    );
    return '$_temp0';
  }

  @override
  String get groupLinesHide => 'Hide who owes whom';

  @override
  String get groupLinesShow => 'Show who owes whom';

  @override
  String get groupLinesLabel => 'Who owes whom';

  @override
  String groupSettledShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count settled expenses',
      one: 'Show 1 settled expense',
    );
    return '$_temp0';
  }

  @override
  String get groupSettledHide => 'Hide settled expenses';

  @override
  String get groupSettledCaption => 'Everyone was settled up after these';

  @override
  String get groupFilterLabel => 'Show groups';

  @override
  String get groupFilterAll => 'All';

  @override
  String get groupFilterOutstanding => 'Outstanding';

  @override
  String get groupFilterIOwe => 'I owe';

  @override
  String get groupFilterOwesMe => 'Owe me';

  @override
  String get groupFilterAllGroups => 'All groups';

  @override
  String get groupFilterOutstandingHint => 'Groups where you owe or are owed';

  @override
  String get groupFilterIOweHint => 'Groups where you owe someone';

  @override
  String get groupFilterOwesMeHint => 'Groups where someone owes you';

  @override
  String get groupFilterEmpty => 'No groups match';

  @override
  String get groupFilterShowAll => 'Show all';

  @override
  String groupFilterButton(String filter) {
    return 'Filter: $filter';
  }

  @override
  String get tripDatesTitle => 'Trip dates';

  @override
  String get tripStarts => 'Starts';

  @override
  String get tripEnds => 'Ends';

  @override
  String get tripNotSet => 'Not set';

  @override
  String get tripNoEnd => 'No end';

  @override
  String get tripPickStart => 'Trip starts';

  @override
  String get tripPickEnd => 'Trip ends';

  @override
  String get tripNoStartDate => 'No start date';

  @override
  String get tripNoEndDate => 'No end date';

  @override
  String get tripEndBeforeStart => 'The trip ends before it starts';

  @override
  String get tripDatesHint =>
      'The day after the trip, everyone who still owes or is owed gets a reminder to settle up.';

  @override
  String tripFrom(String date) {
    return 'From $date';
  }

  @override
  String tripUntil(String date) {
    return 'Until $date';
  }

  @override
  String tripRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String tripChipLabel(String dates) {
    return 'Trip dates: $dates';
  }

  @override
  String get nudgeTitle => 'Settle-up reminders';

  @override
  String get nudgeOff => 'Off';

  @override
  String get nudgeWeekly => 'Weekly';

  @override
  String get nudgeMonthly => 'Monthly';

  @override
  String get nudgeHintOff => 'No automatic reminders. You can still remind people from Balances.';

  @override
  String nudgeHintWeekly(String weekday) {
    return 'Every $weekday, everyone who owes or is owed gets a reminder.';
  }

  @override
  String get nudgeHintMonthly =>
      'On the 1st of every month, everyone who owes or is owed gets a reminder.';

  @override
  String nudgeNext(String date) {
    return 'Next reminder: $date';
  }

  @override
  String get nudgeActivity => 'Reminder to settle up sent';

  @override
  String get nudgeActivityTripEnd => 'The trip is over: reminder to settle up sent';

  @override
  String nudgeSettingWeekly(String actor) {
    return '$actor turned on weekly settle-up reminders';
  }

  @override
  String nudgeSettingMonthly(String actor) {
    return '$actor turned on monthly settle-up reminders';
  }

  @override
  String nudgeSettingOff(String actor) {
    return '$actor turned off settle-up reminders';
  }

  @override
  String get boardTitle => 'Group notes';

  @override
  String get boardHint =>
      'Address, Wi-Fi, door codes, phone numbers — anything the group should know';

  @override
  String get boardHelp => 'Everyone in the group can see and edit these notes.';

  @override
  String boardLastEdited(String name, String date) {
    return 'Last edited by $name · $date';
  }

  @override
  String get boardSaved => 'Notes saved';

  @override
  String boardTooLong(String max) {
    return 'Notes can be up to $max characters';
  }

  @override
  String boardCount(String count, String max) {
    return '$count / $max';
  }

  @override
  String get boardChip => 'Notes';

  @override
  String get boardOpen => 'Open the group notes';

  @override
  String get boardEmpty => 'No notes yet';

  @override
  String boardActivity(String actor) {
    return '$actor updated the group notes';
  }

  @override
  String get boardDiscardBody => 'Your changes to the notes will be lost.';

  @override
  String get boardReadOnly => 'This group is archived, so its notes can\'t be changed.';
}
