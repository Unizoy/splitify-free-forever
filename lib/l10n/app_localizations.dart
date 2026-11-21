import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// App name shown in the task switcher and app bar.
  ///
  /// In en, this message translates to:
  /// **'Splitify Free Forever'**
  String get appTitle;

  /// Shown when a required build setting is missing.
  ///
  /// In en, this message translates to:
  /// **'App is not configured'**
  String get envErrorTitle;

  /// Screen-reader label of a busy button or loader.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// Snackbar for actions built in a later update.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Screen-reader word after a required field label.
  ///
  /// In en, this message translates to:
  /// **'required'**
  String get required;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// Avatar stack overflow bubble.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String moreCount(int count);

  /// Screen-reader text of the avatar overflow bubble.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more person} other{{count} more people}}'**
  String moreMembers(int count);

  /// Screen-reader text of carousel dots.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String pageDots(int index, int total);

  /// Screen-reader value of the arc gauge.
  ///
  /// In en, this message translates to:
  /// **'{percent} percent'**
  String gaugeSemantics(int percent);

  /// No description provided for @navGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get navGroups;

  /// No description provided for @navFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get navFriends;

  /// No description provided for @navActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// Amber + button next to the nav bar.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// Marker on rows saved on the phone but not on the server.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get notSyncedYet;

  /// No description provided for @notSyncedYetHint.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone. It syncs when you are back online.'**
  String get notSyncedYetHint;

  /// No description provided for @youAreOwed.
  ///
  /// In en, this message translates to:
  /// **'You are owed'**
  String get youAreOwed;

  /// No description provided for @youOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get youOwe;

  /// No description provided for @settled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get settled;

  /// No description provided for @allSettled.
  ///
  /// In en, this message translates to:
  /// **'All settled'**
  String get allSettled;

  /// No description provided for @settleUp.
  ///
  /// In en, this message translates to:
  /// **'Settle up'**
  String get settleUp;

  /// No description provided for @overall.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get overall;

  /// Welcome headline, first line (serif, lowercase).
  ///
  /// In en, this message translates to:
  /// **'split it.'**
  String get welcomeLead;

  /// Welcome headline, highlighted second line.
  ///
  /// In en, this message translates to:
  /// **'settle it.'**
  String get welcomeHighlight;

  /// No description provided for @welcomeBadge.
  ///
  /// In en, this message translates to:
  /// **'Free forever · no ads'**
  String get welcomeBadge;

  /// Label inside the dashed circle button, two lines.
  ///
  /// In en, this message translates to:
  /// **'Get\nstarted'**
  String get getStarted;

  /// No description provided for @welcomeFooter.
  ///
  /// In en, this message translates to:
  /// **'Open source · made in India'**
  String get welcomeFooter;

  /// Groups home hero headline (serif, lowercase).
  ///
  /// In en, this message translates to:
  /// **'split it.\nsettle it.'**
  String get groupsHero;

  /// No description provided for @noGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get noGroupsYet;

  /// No description provided for @glassEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add a group to start splitting bills.'**
  String get glassEmptyHint;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create a group'**
  String get createGroup;

  /// No description provided for @joinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join a group'**
  String get joinGroup;

  /// No description provided for @newShort.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newShort;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @joinGroupShort.
  ///
  /// In en, this message translates to:
  /// **'Join group'**
  String get joinGroupShort;

  /// No description provided for @joinShort.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinShort;

  /// No description provided for @activeGroups.
  ///
  /// In en, this message translates to:
  /// **'Active groups · {count}'**
  String activeGroups(int count);

  /// No description provided for @emptyGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first group'**
  String get emptyGroupsTitle;

  /// No description provided for @emptyGroupsBody.
  ///
  /// In en, this message translates to:
  /// **'Trips, flatmates, couples — add the people you split with.'**
  String get emptyGroupsBody;

  /// No description provided for @archivedGroups.
  ///
  /// In en, this message translates to:
  /// **'Archived groups'**
  String get archivedGroups;

  /// No description provided for @groupsOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Changes sync when you\'re back.'**
  String get groupsOffline;

  /// No description provided for @groupsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your groups'**
  String get groupsLoading;

  /// No description provided for @editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get editGroup;

  /// No description provided for @groupFormSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Give it a name and pick what it is for.'**
  String get groupFormSubtitle;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameLabel;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Goa trip, Flat 4B…'**
  String get groupNameHint;

  /// No description provided for @groupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a group name'**
  String get groupNameRequired;

  /// No description provided for @groupNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the name under 60 letters'**
  String get groupNameTooLong;

  /// No description provided for @groupTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get groupTypeLabel;

  /// No description provided for @groupTypeTrip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get groupTypeTrip;

  /// No description provided for @groupTypeHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get groupTypeHome;

  /// No description provided for @groupTypeCouple.
  ///
  /// In en, this message translates to:
  /// **'Couple'**
  String get groupTypeCouple;

  /// No description provided for @groupTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get groupTypeOther;

  /// No description provided for @mainCurrency.
  ///
  /// In en, this message translates to:
  /// **'Main currency'**
  String get mainCurrency;

  /// No description provided for @mainCurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'Default for new expenses. Expenses already added keep their currency.'**
  String get mainCurrencyHint;

  /// No description provided for @coverHint.
  ///
  /// In en, this message translates to:
  /// **'Every group gets its own generated cover.'**
  String get coverHint;

  /// No description provided for @createGroupButton.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get createGroupButton;

  /// No description provided for @groupSaved.
  ///
  /// In en, this message translates to:
  /// **'Group saved'**
  String get groupSaved;

  /// No description provided for @groupMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String groupMembersCount(int count);

  /// No description provided for @groupTabExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get groupTabExpenses;

  /// No description provided for @groupTabBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get groupTabBalances;

  /// No description provided for @groupTabTotals.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get groupTabTotals;

  /// No description provided for @groupNoExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get groupNoExpensesTitle;

  /// No description provided for @groupNoExpensesBody.
  ///
  /// In en, this message translates to:
  /// **'Add the first bill and Splitify splits it for you.'**
  String get groupNoExpensesBody;

  /// No description provided for @groupBalancesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Balances show up here'**
  String get groupBalancesEmptyTitle;

  /// No description provided for @groupBalancesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Once the group has expenses, you see who owes whom.'**
  String get groupBalancesEmptyBody;

  /// No description provided for @groupTotalsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Totals show up here'**
  String get groupTotalsEmptyTitle;

  /// No description provided for @groupTotalsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Total spent and each person\'s share, once there are expenses.'**
  String get groupTotalsEmptyBody;

  /// No description provided for @groupArchivedBanner.
  ///
  /// In en, this message translates to:
  /// **'This group is archived. Unarchive it to add expenses.'**
  String get groupArchivedBanner;

  /// No description provided for @groupNotFound.
  ///
  /// In en, this message translates to:
  /// **'This group is not on this phone.'**
  String get groupNotFound;

  /// No description provided for @archiveGroup.
  ///
  /// In en, this message translates to:
  /// **'Archive group'**
  String get archiveGroup;

  /// No description provided for @unarchiveGroup.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchiveGroup;

  /// No description provided for @groupArchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Group archived'**
  String get groupArchivedDone;

  /// No description provided for @groupUnarchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Group is active again'**
  String get groupUnarchivedDone;

  /// No description provided for @groupSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Group settings'**
  String get groupSettingsTitle;

  /// No description provided for @membersSection.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersSection;

  /// No description provided for @addMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get addMember;

  /// No description provided for @addMemberHint.
  ///
  /// In en, this message translates to:
  /// **'Add someone by name. They can join later and claim this spot.'**
  String get addMemberHint;

  /// No description provided for @memberNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get memberNameLabel;

  /// No description provided for @memberNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a name (1 to 50 letters)'**
  String get memberNameInvalid;

  /// No description provided for @memberColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get memberColour;

  /// No description provided for @memberColourOption.
  ///
  /// In en, this message translates to:
  /// **'Colour {index}'**
  String memberColourOption(int index);

  /// No description provided for @memberOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get memberOwner;

  /// No description provided for @memberNameOnly.
  ///
  /// In en, this message translates to:
  /// **'Not joined yet'**
  String get memberNameOnly;

  /// No description provided for @memberClaimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed this spot'**
  String get memberClaimed;

  /// No description provided for @memberYouSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String memberYouSuffix(String name);

  /// No description provided for @renameMember.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameMember;

  /// No description provided for @unlinkMember.
  ///
  /// In en, this message translates to:
  /// **'Unlink account'**
  String get unlinkMember;

  /// No description provided for @unlinkMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlink {name}?'**
  String unlinkMemberTitle(String name);

  /// No description provided for @unlinkMemberBody.
  ///
  /// In en, this message translates to:
  /// **'This spot becomes name-only again and keeps all its expenses. Use it when the wrong person claimed it.'**
  String get unlinkMemberBody;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get removeMember;

  /// No description provided for @removeMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeMemberTitle(String name);

  /// No description provided for @removeMemberBody.
  ///
  /// In en, this message translates to:
  /// **'This works only when they are settled up in every currency.'**
  String get removeMemberBody;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// No description provided for @leaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this group?'**
  String get leaveGroupTitle;

  /// No description provided for @leaveGroupBody.
  ///
  /// In en, this message translates to:
  /// **'You can leave once you are settled up. Join again any time with the invite code.'**
  String get leaveGroupBody;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroup;

  /// No description provided for @deleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this group?'**
  String get deleteGroupTitle;

  /// No description provided for @deleteGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone loses access. You can restore it for 30 days from Account → Deleted groups.'**
  String get deleteGroupBody;

  /// No description provided for @groupDeletedDone.
  ///
  /// In en, this message translates to:
  /// **'Group deleted'**
  String get groupDeletedDone;

  /// No description provided for @groupErrorNonzeroBalance.
  ///
  /// In en, this message translates to:
  /// **'Settle up first. This person still has a balance in this group.'**
  String get groupErrorNonzeroBalance;

  /// No description provided for @groupErrorNotMember.
  ///
  /// In en, this message translates to:
  /// **'You\'re not a member of this group any more.'**
  String get groupErrorNotMember;

  /// No description provided for @groupErrorGroupFull.
  ///
  /// In en, this message translates to:
  /// **'This group already has 100 members.'**
  String get groupErrorGroupFull;

  /// No description provided for @groupErrorAlreadyClaimed.
  ///
  /// In en, this message translates to:
  /// **'Someone already claimed that spot. Pick another one.'**
  String get groupErrorAlreadyClaimed;

  /// No description provided for @groupErrorMemberNotFound.
  ///
  /// In en, this message translates to:
  /// **'That person is no longer in this group.'**
  String get groupErrorMemberNotFound;

  /// No description provided for @groupErrorNotClaimed.
  ///
  /// In en, this message translates to:
  /// **'That spot is not linked to an account.'**
  String get groupErrorNotClaimed;

  /// No description provided for @groupErrorClaimRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick your name to join this group.'**
  String get groupErrorClaimRequired;

  /// No description provided for @deletedGroups.
  ///
  /// In en, this message translates to:
  /// **'Deleted groups'**
  String get deletedGroups;

  /// No description provided for @deletedGroupsBody.
  ///
  /// In en, this message translates to:
  /// **'Groups you deleted. Restore one within 30 days.'**
  String get deletedGroupsBody;

  /// No description provided for @deletedGroupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No deleted groups'**
  String get deletedGroupsEmpty;

  /// No description provided for @deletedGroupsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Groups you delete show up here for 30 days.'**
  String get deletedGroupsEmptyBody;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Last day to restore} =1{1 day left} other{{days} days left}}'**
  String restoreDaysLeft(int days);

  /// No description provided for @groupRestoredDone.
  ///
  /// In en, this message translates to:
  /// **'Group restored'**
  String get groupRestoredDone;

  /// No description provided for @restoreExpired.
  ///
  /// In en, this message translates to:
  /// **'Too late to restore'**
  String get restoreExpired;

  /// No description provided for @invitePeople.
  ///
  /// In en, this message translates to:
  /// **'Invite people'**
  String get invitePeople;

  /// No description provided for @inviteBody.
  ///
  /// In en, this message translates to:
  /// **'Friends scan this QR or type the code in Groups → Join.'**
  String get inviteBody;

  /// No description provided for @inviteQrLabel.
  ///
  /// In en, this message translates to:
  /// **'QR code for invite code {code}'**
  String inviteQrLabel(String code);

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @shareInvite.
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get shareInvite;

  /// No description provided for @shareInviteText.
  ///
  /// In en, this message translates to:
  /// **'Join my group “{name}” on Splitify Free Forever: code {code}'**
  String shareInviteText(String name, String code);

  /// No description provided for @resetCode.
  ///
  /// In en, this message translates to:
  /// **'Reset code'**
  String get resetCode;

  /// No description provided for @resetCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the invite code?'**
  String get resetCodeTitle;

  /// No description provided for @resetCodeBody.
  ///
  /// In en, this message translates to:
  /// **'The old code and QR stop working at once.'**
  String get resetCodeBody;

  /// No description provided for @codeResetDone.
  ///
  /// In en, this message translates to:
  /// **'New code ready'**
  String get codeResetDone;

  /// No description provided for @inviteNoCode.
  ///
  /// In en, this message translates to:
  /// **'This group is not on the server yet. Connect to the internet to get its invite code.'**
  String get inviteNoCode;

  /// No description provided for @joinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Type the invite code or scan the QR a friend shows you.'**
  String get joinSubtitle;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get enterCode;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQr;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCodeLabel;

  /// No description provided for @inviteCodeHint.
  ///
  /// In en, this message translates to:
  /// **'ABCD-EFGH'**
  String get inviteCodeHint;

  /// No description provided for @findGroup.
  ///
  /// In en, this message translates to:
  /// **'Find group'**
  String get findGroup;

  /// No description provided for @joinInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match any group'**
  String get joinInvalidCode;

  /// No description provided for @joinRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many tries, wait a bit'**
  String get joinRateLimited;

  /// No description provided for @joinNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'Joining needs internet'**
  String get joinNeedsInternet;

  /// No description provided for @joinArchivedNotice.
  ///
  /// In en, this message translates to:
  /// **'This group is archived. You can join, but it is read-only.'**
  String get joinArchivedNotice;

  /// No description provided for @joinAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You\'re already in this group.'**
  String get joinAlreadyMember;

  /// No description provided for @joinWhoAreYou.
  ///
  /// In en, this message translates to:
  /// **'Are you one of these people?'**
  String get joinWhoAreYou;

  /// No description provided for @joinWhoAreYouBody.
  ///
  /// In en, this message translates to:
  /// **'Pick your name to keep the expenses already added for you.'**
  String get joinWhoAreYouBody;

  /// No description provided for @joinAsName.
  ///
  /// In en, this message translates to:
  /// **'I\'m {name}'**
  String joinAsName(String name);

  /// No description provided for @joinNewHere.
  ///
  /// In en, this message translates to:
  /// **'I\'m new here'**
  String get joinNewHere;

  /// No description provided for @joinAsCta.
  ///
  /// In en, this message translates to:
  /// **'Join as {name}'**
  String joinAsCta(String name);

  /// No description provided for @openGroup.
  ///
  /// In en, this message translates to:
  /// **'Open group'**
  String get openGroup;

  /// No description provided for @joinOtherCode.
  ///
  /// In en, this message translates to:
  /// **'Use another code'**
  String get joinOtherCode;

  /// No description provided for @joinScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan invite QR'**
  String get joinScanTitle;

  /// No description provided for @joinScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the invite QR on your friend\'s phone.'**
  String get joinScanHint;

  /// No description provided for @joinQrInvalid.
  ///
  /// In en, this message translates to:
  /// **'That QR is not a Splitify invite'**
  String get joinQrInvalid;

  /// No description provided for @joinedGroup.
  ///
  /// In en, this message translates to:
  /// **'You joined {name}'**
  String joinedGroup(String name);

  /// No description provided for @friendsHero.
  ///
  /// In en, this message translates to:
  /// **'your people,\nsquared up.'**
  String get friendsHero;

  /// No description provided for @emptyFriendsTitle.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get emptyFriendsTitle;

  /// No description provided for @emptyFriendsBody.
  ///
  /// In en, this message translates to:
  /// **'People you share a group with show up here.'**
  String get emptyFriendsBody;

  /// No description provided for @activityHero.
  ///
  /// In en, this message translates to:
  /// **'every rupee,\naccounted for.'**
  String get activityHero;

  /// No description provided for @emptyActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get emptyActivityTitle;

  /// No description provided for @emptyActivityBody.
  ///
  /// In en, this message translates to:
  /// **'Expenses, payments and comments show up here.'**
  String get emptyActivityBody;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @yourAccount.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get yourAccount;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountSettings;

  /// No description provided for @walletBrand.
  ///
  /// In en, this message translates to:
  /// **'SPLITIFY'**
  String get walletBrand;

  /// No description provided for @overallBalance.
  ///
  /// In en, this message translates to:
  /// **'Overall balance'**
  String get overallBalance;

  /// Zero balance placeholder until the money engine formats amounts.
  ///
  /// In en, this message translates to:
  /// **'₹0'**
  String get zeroRupees;

  /// No description provided for @acrossGroups.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No groups yet} =1{Across 1 group} other{Across {count} groups}}'**
  String acrossGroups(int count);

  /// No description provided for @yourSpending.
  ///
  /// In en, this message translates to:
  /// **'Your spending'**
  String get yourSpending;

  /// No description provided for @yourStats.
  ///
  /// In en, this message translates to:
  /// **'Your stats'**
  String get yourStats;

  /// No description provided for @statThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Spent this\nmonth'**
  String get statThisMonth;

  /// No description provided for @statGroups.
  ///
  /// In en, this message translates to:
  /// **'Active\ngroups'**
  String get statGroups;

  /// No description provided for @statPeople.
  ///
  /// In en, this message translates to:
  /// **'People you\nsplit with'**
  String get statPeople;

  /// No description provided for @statExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses\nadded'**
  String get statExpenses;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @preferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get preferencesSubtitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceHint.
  ///
  /// In en, this message translates to:
  /// **'Choose how Splitify looks. System follows your phone\'s setting.'**
  String get appearanceHint;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @aboutLicences.
  ///
  /// In en, this message translates to:
  /// **'About & licences'**
  String get aboutLicences;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @celebrationLead.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get celebrationLead;

  /// No description provided for @celebrationHighlight.
  ///
  /// In en, this message translates to:
  /// **'settled'**
  String get celebrationHighlight;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @stepAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get stepAmount;

  /// No description provided for @stepPaidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get stepPaidBy;

  /// No description provided for @stepSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get stepSplit;

  /// No description provided for @stepDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get stepDetails;

  /// No description provided for @stepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get stepReview;

  /// No description provided for @stepDone.
  ///
  /// In en, this message translates to:
  /// **'{label}, done'**
  String stepDone(String label);

  /// No description provided for @stepCurrent.
  ///
  /// In en, this message translates to:
  /// **'{label}, current step'**
  String stepCurrent(String label);

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'How would you like to sign in?'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use Google or get a 6-digit code by email. The same email is always the same account.'**
  String get signInSubtitle;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @googleSoon.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is coming soon. Use your email for now.'**
  String get googleSoon;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @devSignIn.
  ///
  /// In en, this message translates to:
  /// **'Developer sign-in'**
  String get devSignIn;

  /// No description provided for @codeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get codeTitle;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent it to {email}. It works for 10 minutes.'**
  String codeSentTo(String email);

  /// No description provided for @codeBoxes.
  ///
  /// In en, this message translates to:
  /// **'6-digit code, {count} of 6 entered'**
  String codeBoxes(int count);

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds} s'**
  String resendIn(int seconds);

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmail;

  /// No description provided for @verifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyCode;

  /// No description provided for @profileConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'What should friends call you?'**
  String get profileConfirmTitle;

  /// No description provided for @profileConfirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your name, photo and UPI ID are shown to people in your groups.'**
  String get profileConfirmSubtitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get nameLabel;

  /// No description provided for @upiLabel.
  ///
  /// In en, this message translates to:
  /// **'UPI ID (optional)'**
  String get upiLabel;

  /// No description provided for @upiHint.
  ///
  /// In en, this message translates to:
  /// **'name@bank'**
  String get upiHint;

  /// No description provided for @scanUpiQr.
  ///
  /// In en, this message translates to:
  /// **'Scan my UPI QR'**
  String get scanUpiQr;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @authErrorInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code is not right. Check it and try again.'**
  String get authErrorInvalidCode;

  /// No description provided for @authErrorExpiredCode.
  ///
  /// In en, this message translates to:
  /// **'This code has expired or is not right. Request a new code.'**
  String get authErrorExpiredCode;

  /// No description provided for @authErrorTooManyTries.
  ///
  /// In en, this message translates to:
  /// **'Too many tries, request a new code'**
  String get authErrorTooManyTries;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter an email like name@example.com'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'You’re offline — connect once to sign in'**
  String get authErrorOffline;

  /// No description provided for @authErrorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled'**
  String get authErrorCancelled;

  /// No description provided for @authErrorNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is not set up in this build yet'**
  String get authErrorNotConfigured;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorUnknown;

  /// No description provided for @devLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Debug builds only. Signs in a test user and creates it on first use.'**
  String get devLoginSubtitle;

  /// No description provided for @devLoginUser.
  ///
  /// In en, this message translates to:
  /// **'Test user {user}'**
  String devLoginUser(String user);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Name, photo, UPI ID, currency'**
  String get profileSubtitle;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @defaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default currency'**
  String get defaultCurrency;

  /// No description provided for @defaultCurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'Used for new groups'**
  String get defaultCurrencyHint;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @needsInternet.
  ///
  /// In en, this message translates to:
  /// **'Needs internet. Connect and try again.'**
  String get needsInternet;

  /// No description provided for @nameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter your name (1 to 50 letters)'**
  String get nameInvalid;

  /// No description provided for @upiInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a UPI ID like name@bank'**
  String get upiInvalid;

  /// No description provided for @upiQrInvalid.
  ///
  /// In en, this message translates to:
  /// **'That QR is not a UPI payment code'**
  String get upiQrInvalid;

  /// No description provided for @scanUpiHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code in your UPI app.'**
  String get scanUpiHint;

  /// No description provided for @chooseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Choose currency'**
  String get chooseCurrency;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'Splitify removes your data from this phone. Your groups stay safe on the server.'**
  String get signOutBody;

  /// No description provided for @cancelLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelLabel;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Your expenses stay in your groups under your name so balances stay right; your profile, photo, UPI ID and sign-in are removed.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This works only online and cannot be undone.'**
  String get deleteAccountWarning;

  /// No description provided for @typeDeleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get typeDeleteLabel;

  /// No description provided for @deleteWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteWord;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountButton;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete your account. Check your connection and try again.'**
  String get deleteAccountFailed;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
