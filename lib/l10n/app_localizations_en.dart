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
  String get notifOffline => 'Offline · showing what\'s on this phone';

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
  String get notifMutedOn => 'Muted · bell only';

  @override
  String get notifMutedOff => 'Not muted';

  @override
  String get notifMutedEmpty => 'You\'re not in any groups yet.';

  @override
  String get notifPushOffBuild =>
      'Push notifications aren\'t set up in this version yet. Everything still shows in the bell.';

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
  String get balBannerMixed => 'You are owed and owe here';

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
    return 'paid $paid · share $share';
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
  String get settleGaugeNone => 'Nothing is owed between them. You can still record it.';

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
    return 'Keep the note under $max characters';
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
    return 'Payment · $date';
  }

  @override
  String get payYouPaid => 'you paid';

  @override
  String get payYouReceived => 'you received';

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
    return '$actor brought the group back';
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
  String actRecurringUpdated(String actor) {
    return '$actor changed a recurring bill';
  }

  @override
  String actRecurringStopped(String actor) {
    return '$actor stopped a recurring bill';
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
      other: '$count people owe you',
      one: '1 person owes you',
    );
    return '$_temp0';
  }

  @override
  String homeYouOwePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'you owe $count people',
      one: 'you owe 1 person',
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
  String expEditPill(String group) {
    return 'Editing · $group';
  }

  @override
  String expOfflinePill(String group) {
    return '$group · saved offline';
  }

  @override
  String get expAmountQuestion => 'How much was it?';

  @override
  String get expDescriptionLabel => 'Description';

  @override
  String get expDescriptionHint => 'Dinner, cab, groceries…';

  @override
  String get expDescriptionMissing => 'Add a short description';

  @override
  String get expDescriptionTooLong => 'Keep it under 120 characters';

  @override
  String expCurrencyLabel(String code) {
    return 'Currency $code';
  }

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
  String expAmountEquals(String amount) {
    return '= $amount';
  }

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
  String get expNext => 'Next';

  @override
  String get expSave => 'Save';

  @override
  String get expSaveExpense => 'Save expense';

  @override
  String get expSaved => 'Expense saved';

  @override
  String get expPaidByQuestion => 'Who paid?';

  @override
  String get expMultiplePeople => 'Multiple people';

  @override
  String get expMultiplePaidNote =>
      'Several people paid for this one. Changing who paid what arrives in a later update.';

  @override
  String get expSplitQuestion => 'How should it be split?';

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
    return '$_temp0 · $amount each';
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
    return '$sum of $total · $left left';
  }

  @override
  String expFooterOver(String sum, String total, String over) {
    return '$sum of $total · $over over';
  }

  @override
  String expFooterDone(String total) {
    return '$total · done';
  }

  @override
  String expFooterPercentLeft(String sum, String left) {
    return '$sum % of 100 % · $left % left';
  }

  @override
  String expFooterPercentOver(String sum, String over) {
    return '$sum % of 100 % · $over % over';
  }

  @override
  String get expFooterPercentDone => '100 % · done';

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
  String get expDetailsQuestion => 'A few details';

  @override
  String get expCategoryLabel => 'Category';

  @override
  String get expDateLabel => 'Date';

  @override
  String get expNotesLabel => 'Notes';

  @override
  String get expNotesHint => 'Anything worth remembering';

  @override
  String get expNotesTooLong => 'Notes can be up to 1000 characters';

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
  String get expReviewQuestion => 'All good?';

  @override
  String get expReviewPaidBy => 'Paid by ';

  @override
  String get expReviewAndSplit => ' and split ';

  @override
  String expHowEqual(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return 'equally between $_temp0';
  }

  @override
  String get expHowExact => 'by exact amounts';

  @override
  String get expHowPercent => 'by percentages';

  @override
  String get expHowShares => 'by shares';

  @override
  String get expHowAdjust => 'with adjustments';

  @override
  String get expSeveralPeople => 'several people';

  @override
  String get expYouLower => 'you';

  @override
  String expOwes(String amount) {
    return 'owes $amount';
  }

  @override
  String expPaidAmount(String amount) {
    return 'paid $amount';
  }

  @override
  String get expOwesNothing => 'owes nothing';

  @override
  String expReviewSummary(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$amount · $_temp0';
  }

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
    return 'Split · $kind';
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
    return 'Change by $name';
  }

  @override
  String get histNotApplied => 'Not applied (a newer edit won)';

  @override
  String get histFormerMember => 'A former member';

  @override
  String histWhen(String date, String time) {
    return '$date · $time';
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
  String get histEmptyBody => 'Changes show up here once they reach the server.';

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
    return 'Keep it under $max characters.';
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
    return 'Deleted by $name · $date';
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
    return 'New expenses in $group start with this split. If the members change, they go back to equal.';
  }

  @override
  String get expDefaultSplitEqualNote => 'Everyone pays the same share.';

  @override
  String get expDefaultSplitSaved => 'Default split saved';

  @override
  String get expPickGroup => 'Add to which group?';

  @override
  String get expNoGroupFirst => 'Create a group first, then add expenses to it.';

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
  String payersMany(String first, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count others',
      one: '1 other',
    );
    return '$first and $_temp0';
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
}
