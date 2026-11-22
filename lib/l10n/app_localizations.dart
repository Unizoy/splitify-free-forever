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

  /// Subtitle of the Notifications screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread} other{{count} unread}}'**
  String notifUnreadCount(int count);

  /// Subtitle of the Notifications screen when nothing is unread.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get notifAllCaughtUp;

  /// No description provided for @notifMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notifMarkAllRead;

  /// No description provided for @notifEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notifEmptyTitle;

  /// No description provided for @notifEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When someone adds an expense with you, pays you or sends a reminder, it shows up here.'**
  String get notifEmptyBody;

  /// Note above the bell list when the refresh could not reach the server.
  ///
  /// In en, this message translates to:
  /// **'Offline · showing what\'s on this phone'**
  String get notifOffline;

  /// No description provided for @notifSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notifSettingsTooltip;

  /// Screen-reader label of the bell button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Notifications} =1{Notifications, 1 unread} other{Notifications, {count} unread}}'**
  String notifBellLabel(int count);

  /// Screen-reader word for the unread dot.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notifUnread;

  /// No description provided for @notifKindExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get notifKindExpenses;

  /// No description provided for @notifKindPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get notifKindPayments;

  /// No description provided for @notifKindReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notifKindReminders;

  /// No description provided for @notifKindComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get notifKindComments;

  /// No description provided for @notifKindGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get notifKindGroups;

  /// No description provided for @notifKindExpensesHint.
  ///
  /// In en, this message translates to:
  /// **'Added, edited, deleted or restored'**
  String get notifKindExpensesHint;

  /// No description provided for @notifKindPaymentsHint.
  ///
  /// In en, this message translates to:
  /// **'Payments recorded with you'**
  String get notifKindPaymentsHint;

  /// No description provided for @notifKindRemindersHint.
  ///
  /// In en, this message translates to:
  /// **'Someone reminds you to settle up'**
  String get notifKindRemindersHint;

  /// No description provided for @notifKindCommentsHint.
  ///
  /// In en, this message translates to:
  /// **'Comments on expenses you\'re in'**
  String get notifKindCommentsHint;

  /// No description provided for @notifKindGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'People joining or leaving, group settings'**
  String get notifKindGroupsHint;

  /// No description provided for @notifSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose what reaches you, and where.'**
  String get notifSettingsHint;

  /// Settings section: push notifications per kind.
  ///
  /// In en, this message translates to:
  /// **'On your phone'**
  String get notifSectionPush;

  /// Settings section: bell list per kind.
  ///
  /// In en, this message translates to:
  /// **'In the app'**
  String get notifSectionInApp;

  /// No description provided for @notifSectionMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted groups'**
  String get notifSectionMuted;

  /// No description provided for @notifMutedHint.
  ///
  /// In en, this message translates to:
  /// **'Muted groups still show in the bell, just without pushes.'**
  String get notifMutedHint;

  /// No description provided for @notifMutedEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in any groups yet.'**
  String get notifMutedEmpty;

  /// Settings banner in builds without Firebase (D-020).
  ///
  /// In en, this message translates to:
  /// **'Push notifications aren\'t set up in this version yet. Everything still shows in the bell.'**
  String get notifPushOffBuild;

  /// No description provided for @notifPushBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked for Splitify on this phone. You\'ll still see everything in the bell.'**
  String get notifPushBlocked;

  /// No description provided for @notifPushNotAsked.
  ///
  /// In en, this message translates to:
  /// **'Push notifications are off for now.'**
  String get notifPushNotAsked;

  /// No description provided for @notifAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get notifAllow;

  /// Value of the Notifications row in Account settings.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get notifRowOn;

  /// Value of the Notifications row when this phone gets no pushes.
  ///
  /// In en, this message translates to:
  /// **'Bell only'**
  String get notifRowBellOnly;

  /// No description provided for @notifPrePromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay in the loop'**
  String get notifPrePromptTitle;

  /// No description provided for @notifPrePromptBody.
  ///
  /// In en, this message translates to:
  /// **'Get a quiet nudge when something changes in your groups.'**
  String get notifPrePromptBody;

  /// No description provided for @notifPrePromptPoint1.
  ///
  /// In en, this message translates to:
  /// **'New expenses you\'re part of'**
  String get notifPrePromptPoint1;

  /// No description provided for @notifPrePromptPoint2.
  ///
  /// In en, this message translates to:
  /// **'Payments and reminders to settle up'**
  String get notifPrePromptPoint2;

  /// No description provided for @notifPrePromptPoint3.
  ///
  /// In en, this message translates to:
  /// **'Comments on your expenses'**
  String get notifPrePromptPoint3;

  /// No description provided for @notifPrePromptAllow.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get notifPrePromptAllow;

  /// No description provided for @notifPrePromptLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notifPrePromptLater;

  /// Remind button on a balance row.
  ///
  /// In en, this message translates to:
  /// **'Remind {name}'**
  String remindTooltip(String name);

  /// No description provided for @remindSent.
  ///
  /// In en, this message translates to:
  /// **'Reminder sent to {name}'**
  String remindSent(String name);

  /// No description provided for @remindThrottled.
  ///
  /// In en, this message translates to:
  /// **'You reminded {name} recently. You can remind again in {hours, plural, =1{1 hour} other{{hours} hours}}.'**
  String remindThrottled(String name, int hours);

  /// Tooltip of the Remind button within the 24 h throttle.
  ///
  /// In en, this message translates to:
  /// **'Reminded. Again in {hours, plural, =1{1 hour} other{{hours} hours}}'**
  String remindedTooltip(int hours);

  /// No description provided for @remindNothingOwed.
  ///
  /// In en, this message translates to:
  /// **'{name} doesn\'t owe you anything here right now.'**
  String remindNothingOwed(String name);

  /// No description provided for @remindNameOnly.
  ///
  /// In en, this message translates to:
  /// **'Only people who joined the app can be reminded.'**
  String get remindNameOnly;

  /// No description provided for @remindFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the reminder. Try again.'**
  String get remindFailed;

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

  /// No description provided for @archivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedLabel;

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

  /// 'You' in the middle of a sentence.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get youLower;

  /// No description provided for @someone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get someone;

  /// No description provided for @statusOwedAndOwe.
  ///
  /// In en, this message translates to:
  /// **'Owed and owing'**
  String get statusOwedAndOwe;

  /// No description provided for @balPillOwed.
  ///
  /// In en, this message translates to:
  /// **'You are owed {amount}'**
  String balPillOwed(String amount);

  /// No description provided for @balPillOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe {amount}'**
  String balPillOwe(String amount);

  /// No description provided for @balBannerOwed.
  ///
  /// In en, this message translates to:
  /// **'You are owed here'**
  String get balBannerOwed;

  /// No description provided for @balBannerOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe here'**
  String get balBannerOwe;

  /// No description provided for @balBannerMixed.
  ///
  /// In en, this message translates to:
  /// **'You are owed and owe here'**
  String get balBannerMixed;

  /// No description provided for @balBannerSettled.
  ///
  /// In en, this message translates to:
  /// **'In this group'**
  String get balBannerSettled;

  /// No description provided for @balBannerSettledLine2.
  ///
  /// In en, this message translates to:
  /// **'You\'re all settled'**
  String get balBannerSettledLine2;

  /// No description provided for @balEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get balEveryone;

  /// No description provided for @balWhoOwesWhom.
  ///
  /// In en, this message translates to:
  /// **'Who owes whom'**
  String get balWhoOwesWhom;

  /// No description provided for @balSuggestedPayments.
  ///
  /// In en, this message translates to:
  /// **'Suggested payments'**
  String get balSuggestedPayments;

  /// No description provided for @balShowOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original debts'**
  String get balShowOriginal;

  /// No description provided for @balShowSimplified.
  ///
  /// In en, this message translates to:
  /// **'Show suggested payments'**
  String get balShowSimplified;

  /// No description provided for @balGetsBack.
  ///
  /// In en, this message translates to:
  /// **'gets back'**
  String get balGetsBack;

  /// No description provided for @balOwes.
  ///
  /// In en, this message translates to:
  /// **'owes'**
  String get balOwes;

  /// No description provided for @balSettledUp.
  ///
  /// In en, this message translates to:
  /// **'settled up'**
  String get balSettledUp;

  /// No description provided for @balPairOwes.
  ///
  /// In en, this message translates to:
  /// **'{from} owes {to}'**
  String balPairOwes(String from, String to);

  /// No description provided for @balYouOwePerson.
  ///
  /// In en, this message translates to:
  /// **'You owe {name}'**
  String balYouOwePerson(String name);

  /// No description provided for @balSettle.
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get balSettle;

  /// No description provided for @balEveryoneSettled.
  ///
  /// In en, this message translates to:
  /// **'Everyone is settled up'**
  String get balEveryoneSettled;

  /// No description provided for @balCurrencySection.
  ///
  /// In en, this message translates to:
  /// **'{code} balances'**
  String balCurrencySection(String code);

  /// No description provided for @balLoadError.
  ///
  /// In en, this message translates to:
  /// **'Balances could not be loaded'**
  String get balLoadError;

  /// No description provided for @totThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get totThisMonth;

  /// No description provided for @totAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get totAllTime;

  /// No description provided for @totSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get totSpent;

  /// No description provided for @totExpenseCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense} other{{count} expenses}}'**
  String totExpenseCount(int count);

  /// No description provided for @totYourShare.
  ///
  /// In en, this message translates to:
  /// **'Your share'**
  String get totYourShare;

  /// No description provided for @totYouPaid.
  ///
  /// In en, this message translates to:
  /// **'You paid'**
  String get totYouPaid;

  /// No description provided for @totEachPerson.
  ///
  /// In en, this message translates to:
  /// **'Each person'**
  String get totEachPerson;

  /// No description provided for @totPaidShare.
  ///
  /// In en, this message translates to:
  /// **'paid {paid} · share {share}'**
  String totPaidShare(String paid, String share);

  /// No description provided for @totEmptyMonthTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing spent this month'**
  String get totEmptyMonthTitle;

  /// No description provided for @totEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No spending yet'**
  String get totEmptyTitle;

  /// No description provided for @totEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add an expense and the totals show up here.'**
  String get totEmptyBody;

  /// No description provided for @totFootnote.
  ///
  /// In en, this message translates to:
  /// **'Payments and loans are not counted as spending.'**
  String get totFootnote;

  /// No description provided for @totCharts.
  ///
  /// In en, this message translates to:
  /// **'See charts'**
  String get totCharts;

  /// No description provided for @settleEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit payment'**
  String get settleEditTitle;

  /// No description provided for @settlePaidSentence.
  ///
  /// In en, this message translates to:
  /// **'{from} paid {to}'**
  String settlePaidSentence(String from, String to);

  /// No description provided for @settleSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap who paid'**
  String get settleSwap;

  /// No description provided for @settleWhoPaid.
  ///
  /// In en, this message translates to:
  /// **'Who paid?'**
  String get settleWhoPaid;

  /// No description provided for @settleWhoReceived.
  ///
  /// In en, this message translates to:
  /// **'Who got the money?'**
  String get settleWhoReceived;

  /// No description provided for @settleChangePerson.
  ///
  /// In en, this message translates to:
  /// **'Change {name}'**
  String settleChangePerson(String name);

  /// No description provided for @settleAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get settleAmount;

  /// No description provided for @settleGaugeOf.
  ///
  /// In en, this message translates to:
  /// **'of {owed} owed'**
  String settleGaugeOf(String owed);

  /// No description provided for @settleGaugeAll.
  ///
  /// In en, this message translates to:
  /// **'settles all of {owed}'**
  String settleGaugeAll(String owed);

  /// No description provided for @settleGaugeOver.
  ///
  /// In en, this message translates to:
  /// **'more than the {owed} owed'**
  String settleGaugeOver(String owed);

  /// No description provided for @settleGaugeNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing is owed between them. You can still record it.'**
  String get settleGaugeNone;

  /// No description provided for @settleUseOwed.
  ///
  /// In en, this message translates to:
  /// **'Pay all {owed}'**
  String settleUseOwed(String owed);

  /// No description provided for @settleMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get settleMethod;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get methodUpi;

  /// No description provided for @methodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get methodBank;

  /// No description provided for @methodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get methodOther;

  /// No description provided for @settleDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get settleDate;

  /// No description provided for @settleNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get settleNote;

  /// No description provided for @settleNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get settleNoteHint;

  /// No description provided for @settleNoteTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the note under {max} characters'**
  String settleNoteTooLong(int max);

  /// No description provided for @settleRecord.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get settleRecord;

  /// No description provided for @settleSave.
  ///
  /// In en, this message translates to:
  /// **'Save payment'**
  String get settleSave;

  /// No description provided for @settleRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get settleRecorded;

  /// No description provided for @settleSaved.
  ///
  /// In en, this message translates to:
  /// **'Payment saved'**
  String get settleSaved;

  /// No description provided for @settleNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to settle here'**
  String get settleNotFoundTitle;

  /// No description provided for @settleNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This group or payment is not on this phone.'**
  String get settleNotFoundBody;

  /// No description provided for @settleSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get settleSuggested;

  /// No description provided for @settleOther.
  ///
  /// In en, this message translates to:
  /// **'Record a different payment'**
  String get settleOther;

  /// No description provided for @settleGroupSettled.
  ///
  /// In en, this message translates to:
  /// **'Everyone in this group is settled up.'**
  String get settleGroupSettled;

  /// No description provided for @settleWithTitle.
  ///
  /// In en, this message translates to:
  /// **'Settle up with'**
  String get settleWithTitle;

  /// No description provided for @allSettledSnack.
  ///
  /// In en, this message translates to:
  /// **'You\'re all settled up'**
  String get allSettledSnack;

  /// No description provided for @payTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payTitle;

  /// No description provided for @payEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit payment'**
  String get payEdit;

  /// No description provided for @payDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete payment'**
  String get payDelete;

  /// No description provided for @payDeleted.
  ///
  /// In en, this message translates to:
  /// **'Payment deleted'**
  String get payDeleted;

  /// No description provided for @payNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment not found'**
  String get payNotFoundTitle;

  /// No description provided for @payNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted, or it has not reached this phone yet.'**
  String get payNotFoundBody;

  /// No description provided for @payMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get payMethodLabel;

  /// No description provided for @payNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get payNoteLabel;

  /// No description provided for @payDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get payDetailsLabel;

  /// No description provided for @payRowCaption.
  ///
  /// In en, this message translates to:
  /// **'Payment · {date}'**
  String payRowCaption(String date);

  /// No description provided for @payYouPaid.
  ///
  /// In en, this message translates to:
  /// **'you paid'**
  String get payYouPaid;

  /// No description provided for @payYouReceived.
  ///
  /// In en, this message translates to:
  /// **'you received'**
  String get payYouReceived;

  /// No description provided for @actFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get actFilterAll;

  /// No description provided for @actFilterExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get actFilterExpenses;

  /// No description provided for @actFilterPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get actFilterPayments;

  /// No description provided for @actFilterComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get actFilterComments;

  /// No description provided for @actFilterGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get actFilterGroups;

  /// No description provided for @actEmptyFilteredTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get actEmptyFilteredTitle;

  /// No description provided for @actEmptyFilteredBody.
  ///
  /// In en, this message translates to:
  /// **'Try another filter, or check back after the next change.'**
  String get actEmptyFilteredBody;

  /// No description provided for @actTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get actTitle;

  /// No description provided for @actRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get actRecent;

  /// No description provided for @actSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all activity'**
  String get actSeeAll;

  /// No description provided for @actGroupCreated.
  ///
  /// In en, this message translates to:
  /// **'{actor} created the group'**
  String actGroupCreated(String actor);

  /// No description provided for @actGroupUpdated.
  ///
  /// In en, this message translates to:
  /// **'{actor} updated the group'**
  String actGroupUpdated(String actor);

  /// No description provided for @actGroupArchived.
  ///
  /// In en, this message translates to:
  /// **'{actor} archived the group'**
  String actGroupArchived(String actor);

  /// No description provided for @actGroupUnarchived.
  ///
  /// In en, this message translates to:
  /// **'{actor} brought the group back'**
  String actGroupUnarchived(String actor);

  /// No description provided for @actGroupDeleted.
  ///
  /// In en, this message translates to:
  /// **'{actor} deleted the group'**
  String actGroupDeleted(String actor);

  /// No description provided for @actGroupRestored.
  ///
  /// In en, this message translates to:
  /// **'{actor} restored the group'**
  String actGroupRestored(String actor);

  /// No description provided for @actMemberAdded.
  ///
  /// In en, this message translates to:
  /// **'{actor} added {member}'**
  String actMemberAdded(String actor, String member);

  /// No description provided for @actMemberJoined.
  ///
  /// In en, this message translates to:
  /// **'{actor} joined the group'**
  String actMemberJoined(String actor);

  /// No description provided for @actMemberClaimed.
  ///
  /// In en, this message translates to:
  /// **'{actor} joined as {member}'**
  String actMemberClaimed(String actor, String member);

  /// No description provided for @actMemberLeft.
  ///
  /// In en, this message translates to:
  /// **'{member} left the group'**
  String actMemberLeft(String member);

  /// No description provided for @actMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'{actor} removed {member}'**
  String actMemberRemoved(String actor, String member);

  /// No description provided for @actExpenseAdded.
  ///
  /// In en, this message translates to:
  /// **'{actor} added “{description}”'**
  String actExpenseAdded(String actor, String description);

  /// No description provided for @actExpenseEdited.
  ///
  /// In en, this message translates to:
  /// **'{actor} edited “{description}”'**
  String actExpenseEdited(String actor, String description);

  /// No description provided for @actExpenseDeleted.
  ///
  /// In en, this message translates to:
  /// **'{actor} deleted “{description}”'**
  String actExpenseDeleted(String actor, String description);

  /// No description provided for @actExpenseRestored.
  ///
  /// In en, this message translates to:
  /// **'{actor} restored “{description}”'**
  String actExpenseRestored(String actor, String description);

  /// No description provided for @actPaymentAdded.
  ///
  /// In en, this message translates to:
  /// **'{actor} recorded a payment from {from} to {to}'**
  String actPaymentAdded(String actor, String from, String to);

  /// No description provided for @actPaymentEdited.
  ///
  /// In en, this message translates to:
  /// **'{actor} edited a payment from {from} to {to}'**
  String actPaymentEdited(String actor, String from, String to);

  /// No description provided for @actPaymentDeleted.
  ///
  /// In en, this message translates to:
  /// **'{actor} deleted a payment from {from} to {to}'**
  String actPaymentDeleted(String actor, String from, String to);

  /// No description provided for @actPaymentRestored.
  ///
  /// In en, this message translates to:
  /// **'{actor} restored a payment from {from} to {to}'**
  String actPaymentRestored(String actor, String from, String to);

  /// No description provided for @actCommentOn.
  ///
  /// In en, this message translates to:
  /// **'{actor} commented on “{description}”'**
  String actCommentOn(String actor, String description);

  /// No description provided for @actCommentAdded.
  ///
  /// In en, this message translates to:
  /// **'{actor} added a comment'**
  String actCommentAdded(String actor);

  /// No description provided for @actCommentDeleted.
  ///
  /// In en, this message translates to:
  /// **'{actor} deleted a comment'**
  String actCommentDeleted(String actor);

  /// No description provided for @actReminderSent.
  ///
  /// In en, this message translates to:
  /// **'{actor} sent a payment reminder'**
  String actReminderSent(String actor);

  /// No description provided for @actSettingsChanged.
  ///
  /// In en, this message translates to:
  /// **'{actor} changed the group settings'**
  String actSettingsChanged(String actor);

  /// No description provided for @actRecurringCreated.
  ///
  /// In en, this message translates to:
  /// **'{actor} set up a recurring bill'**
  String actRecurringCreated(String actor);

  /// No description provided for @actRecurringUpdated.
  ///
  /// In en, this message translates to:
  /// **'{actor} changed a recurring bill'**
  String actRecurringUpdated(String actor);

  /// No description provided for @actRecurringStopped.
  ///
  /// In en, this message translates to:
  /// **'{actor} stopped a recurring bill'**
  String actRecurringStopped(String actor);

  /// No description provided for @actImportCompleted.
  ///
  /// In en, this message translates to:
  /// **'{actor} imported expenses from Splitwise'**
  String actImportCompleted(String actor);

  /// No description provided for @actUnknown.
  ///
  /// In en, this message translates to:
  /// **'{actor} made a change'**
  String actUnknown(String actor);

  /// No description provided for @homeGroupsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No groups yet} =1{1 group} other{{count} groups}}'**
  String homeGroupsCount(int count);

  /// No description provided for @homePeopleOweYou.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person owes you} other{{count} people owe you}}'**
  String homePeopleOweYou(int count);

  /// No description provided for @homeYouOwePeople.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{you owe 1 person} other{you owe {count} people}}'**
  String homeYouOwePeople(int count);

  /// No description provided for @walletBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Balances by group'**
  String get walletBreakdownTitle;

  /// No description provided for @walletBreakdownEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re all settled up in every group.'**
  String get walletBreakdownEmpty;

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

  /// No description provided for @expEditPill.
  ///
  /// In en, this message translates to:
  /// **'Editing · {group}'**
  String expEditPill(String group);

  /// No description provided for @expOfflinePill.
  ///
  /// In en, this message translates to:
  /// **'{group} · saved offline'**
  String expOfflinePill(String group);

  /// No description provided for @expAmountQuestion.
  ///
  /// In en, this message translates to:
  /// **'How much was it?'**
  String get expAmountQuestion;

  /// No description provided for @expDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get expDescriptionLabel;

  /// No description provided for @expDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Dinner, cab, groceries…'**
  String get expDescriptionHint;

  /// No description provided for @expDescriptionMissing.
  ///
  /// In en, this message translates to:
  /// **'Add a short description'**
  String get expDescriptionMissing;

  /// No description provided for @expDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep it under 120 characters'**
  String get expDescriptionTooLong;

  /// No description provided for @expCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency {code}'**
  String expCurrencyLabel(String code);

  /// No description provided for @expAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expAmountLabel;

  /// No description provided for @expAmountErrorDecimals.
  ///
  /// In en, this message translates to:
  /// **'{currency} allows {count, plural, =0{no decimals} =1{1 decimal} other{{count} decimals}}'**
  String expAmountErrorDecimals(String currency, int count);

  /// No description provided for @expAmountErrorDivide.
  ///
  /// In en, this message translates to:
  /// **'You can\'t divide by 0'**
  String get expAmountErrorDivide;

  /// No description provided for @expAmountErrorNotPositive.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above zero'**
  String get expAmountErrorNotPositive;

  /// No description provided for @expAmountErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That amount is too large'**
  String get expAmountErrorTooLarge;

  /// No description provided for @expAmountErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the amount'**
  String get expAmountErrorInvalid;

  /// No description provided for @expAmountEquals.
  ///
  /// In en, this message translates to:
  /// **'= {amount}'**
  String expAmountEquals(String amount);

  /// No description provided for @expKeyDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get expKeyDelete;

  /// No description provided for @expKeyPlus.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get expKeyPlus;

  /// No description provided for @expKeyMinus.
  ///
  /// In en, this message translates to:
  /// **'Minus'**
  String get expKeyMinus;

  /// No description provided for @expKeyTimes.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get expKeyTimes;

  /// No description provided for @expKeyDivide.
  ///
  /// In en, this message translates to:
  /// **'Divided by'**
  String get expKeyDivide;

  /// No description provided for @expKeyDot.
  ///
  /// In en, this message translates to:
  /// **'Decimal point'**
  String get expKeyDot;

  /// No description provided for @expNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get expNext;

  /// No description provided for @expSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get expSave;

  /// No description provided for @expSaveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save expense'**
  String get expSaveExpense;

  /// No description provided for @expSaved.
  ///
  /// In en, this message translates to:
  /// **'Expense saved'**
  String get expSaved;

  /// No description provided for @expPaidByQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who paid?'**
  String get expPaidByQuestion;

  /// No description provided for @expMultiplePeople.
  ///
  /// In en, this message translates to:
  /// **'Multiple people'**
  String get expMultiplePeople;

  /// No description provided for @expMultiplePaidNote.
  ///
  /// In en, this message translates to:
  /// **'Several people paid for this one. Changing who paid what arrives in a later update.'**
  String get expMultiplePaidNote;

  /// No description provided for @expSplitQuestion.
  ///
  /// In en, this message translates to:
  /// **'How should it be split?'**
  String get expSplitQuestion;

  /// No description provided for @expSplitEqual.
  ///
  /// In en, this message translates to:
  /// **'Equally'**
  String get expSplitEqual;

  /// No description provided for @expSplitExact.
  ///
  /// In en, this message translates to:
  /// **'Exact amounts'**
  String get expSplitExact;

  /// No description provided for @expSplitPercent.
  ///
  /// In en, this message translates to:
  /// **'Percentages'**
  String get expSplitPercent;

  /// No description provided for @expSplitShares.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get expSplitShares;

  /// No description provided for @expSplitAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get expSplitAdjust;

  /// No description provided for @expSplitEqualHint.
  ///
  /// In en, this message translates to:
  /// **'Everyone ticked pays the same.'**
  String get expSplitEqualHint;

  /// No description provided for @expSplitExactHint.
  ///
  /// In en, this message translates to:
  /// **'Type what each person owes.'**
  String get expSplitExactHint;

  /// No description provided for @expSplitPercentHint.
  ///
  /// In en, this message translates to:
  /// **'Give each person a percentage.'**
  String get expSplitPercentHint;

  /// No description provided for @expSplitSharesHint.
  ///
  /// In en, this message translates to:
  /// **'Give each person shares, like 2 for a couple.'**
  String get expSplitSharesHint;

  /// No description provided for @expSplitAdjustHint.
  ///
  /// In en, this message translates to:
  /// **'Add or take away for someone; the rest is split equally.'**
  String get expSplitAdjustHint;

  /// No description provided for @expNotIncluded.
  ///
  /// In en, this message translates to:
  /// **'Not included'**
  String get expNotIncluded;

  /// No description provided for @expIncludeMember.
  ///
  /// In en, this message translates to:
  /// **'Include {name}'**
  String expIncludeMember(String name);

  /// No description provided for @expMemberAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount for {name}'**
  String expMemberAmountLabel(String name);

  /// No description provided for @expMemberPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Percentage for {name}'**
  String expMemberPercentLabel(String name);

  /// No description provided for @expMemberSharesLabel.
  ///
  /// In en, this message translates to:
  /// **'Shares for {name}'**
  String expMemberSharesLabel(String name);

  /// No description provided for @expMemberAdjustLabel.
  ///
  /// In en, this message translates to:
  /// **'Adjustment for {name}'**
  String expMemberAdjustLabel(String name);

  /// No description provided for @expFooterEqual.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}} · {amount} each'**
  String expFooterEqual(int count, String amount);

  /// No description provided for @expFooterPeople.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String expFooterPeople(int count);

  /// No description provided for @expFooterLeft.
  ///
  /// In en, this message translates to:
  /// **'{sum} of {total} · {left} left'**
  String expFooterLeft(String sum, String total, String left);

  /// No description provided for @expFooterOver.
  ///
  /// In en, this message translates to:
  /// **'{sum} of {total} · {over} over'**
  String expFooterOver(String sum, String total, String over);

  /// No description provided for @expFooterDone.
  ///
  /// In en, this message translates to:
  /// **'{total} · done'**
  String expFooterDone(String total);

  /// No description provided for @expFooterPercentLeft.
  ///
  /// In en, this message translates to:
  /// **'{sum} % of 100 % · {left} % left'**
  String expFooterPercentLeft(String sum, String left);

  /// No description provided for @expFooterPercentOver.
  ///
  /// In en, this message translates to:
  /// **'{sum} % of 100 % · {over} % over'**
  String expFooterPercentOver(String sum, String over);

  /// No description provided for @expFooterPercentDone.
  ///
  /// In en, this message translates to:
  /// **'100 % · done'**
  String get expFooterPercentDone;

  /// No description provided for @expFooterShares.
  ///
  /// In en, this message translates to:
  /// **'{count} shares in total'**
  String expFooterShares(String count);

  /// No description provided for @expFooterAdjust.
  ///
  /// In en, this message translates to:
  /// **'{rest} split equally after adjustments'**
  String expFooterAdjust(String rest);

  /// No description provided for @expErrNoParticipants.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one person'**
  String get expErrNoParticipants;

  /// No description provided for @expErrNoShares.
  ///
  /// In en, this message translates to:
  /// **'Give someone at least one share'**
  String get expErrNoShares;

  /// No description provided for @expErrNegativeShare.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s share can\'t go below {zero}'**
  String expErrNegativeShare(String name, String zero);

  /// No description provided for @expErrNegativeShareAny.
  ///
  /// In en, this message translates to:
  /// **'A share can\'t go below {zero}'**
  String expErrNegativeShareAny(String zero);

  /// No description provided for @expErrPercentRange.
  ///
  /// In en, this message translates to:
  /// **'Percentages go from 0 to 100'**
  String get expErrPercentRange;

  /// No description provided for @expErrAdjustOver.
  ///
  /// In en, this message translates to:
  /// **'Adjustments are {over} more than the total'**
  String expErrAdjustOver(String over);

  /// No description provided for @expErrInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Check the numbers you typed'**
  String get expErrInvalidInput;

  /// No description provided for @expErrNeedAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount first'**
  String get expErrNeedAmount;

  /// No description provided for @expErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'This split doesn\'t add up yet'**
  String get expErrGeneric;

  /// No description provided for @expDetailsQuestion.
  ///
  /// In en, this message translates to:
  /// **'A few details'**
  String get expDetailsQuestion;

  /// No description provided for @expCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expCategoryLabel;

  /// No description provided for @expDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get expDateLabel;

  /// No description provided for @expNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get expNotesLabel;

  /// No description provided for @expNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Anything worth remembering'**
  String get expNotesHint;

  /// No description provided for @expNotesTooLong.
  ///
  /// In en, this message translates to:
  /// **'Notes can be up to 1000 characters'**
  String get expNotesTooLong;

  /// No description provided for @expToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get expToday;

  /// No description provided for @expYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get expYesterday;

  /// No description provided for @expPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get expPickDate;

  /// No description provided for @expPrevMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get expPrevMonth;

  /// No description provided for @expNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get expNextMonth;

  /// No description provided for @expReviewQuestion.
  ///
  /// In en, this message translates to:
  /// **'All good?'**
  String get expReviewQuestion;

  /// No description provided for @expReviewPaidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by '**
  String get expReviewPaidBy;

  /// No description provided for @expReviewAndSplit.
  ///
  /// In en, this message translates to:
  /// **' and split '**
  String get expReviewAndSplit;

  /// No description provided for @expHowEqual.
  ///
  /// In en, this message translates to:
  /// **'equally between {count, plural, =1{1 person} other{{count} people}}'**
  String expHowEqual(int count);

  /// No description provided for @expHowExact.
  ///
  /// In en, this message translates to:
  /// **'by exact amounts'**
  String get expHowExact;

  /// No description provided for @expHowPercent.
  ///
  /// In en, this message translates to:
  /// **'by percentages'**
  String get expHowPercent;

  /// No description provided for @expHowShares.
  ///
  /// In en, this message translates to:
  /// **'by shares'**
  String get expHowShares;

  /// No description provided for @expHowAdjust.
  ///
  /// In en, this message translates to:
  /// **'with adjustments'**
  String get expHowAdjust;

  /// No description provided for @expSeveralPeople.
  ///
  /// In en, this message translates to:
  /// **'several people'**
  String get expSeveralPeople;

  /// No description provided for @expYouLower.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get expYouLower;

  /// No description provided for @expOwes.
  ///
  /// In en, this message translates to:
  /// **'owes {amount}'**
  String expOwes(String amount);

  /// No description provided for @expPaidAmount.
  ///
  /// In en, this message translates to:
  /// **'paid {amount}'**
  String expPaidAmount(String amount);

  /// No description provided for @expOwesNothing.
  ///
  /// In en, this message translates to:
  /// **'owes nothing'**
  String get expOwesNothing;

  /// No description provided for @expReviewSummary.
  ///
  /// In en, this message translates to:
  /// **'{amount} · {count, plural, =1{1 person} other{{count} people}}'**
  String expReviewSummary(String amount, int count);

  /// No description provided for @expNoExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get expNoExpensesTitle;

  /// No description provided for @expNoExpensesBody.
  ///
  /// In en, this message translates to:
  /// **'Add the first one. It takes a few seconds.'**
  String get expNoExpensesBody;

  /// No description provided for @expLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load expenses'**
  String get expLoadError;

  /// No description provided for @expLoadErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Your data is safe on this phone. Try again in a moment.'**
  String get expLoadErrorBody;

  /// No description provided for @expPaidCaption.
  ///
  /// In en, this message translates to:
  /// **'{name} paid {amount}'**
  String expPaidCaption(String name, String amount);

  /// No description provided for @expSeveralPaidCaption.
  ///
  /// In en, this message translates to:
  /// **'{count} people paid {amount}'**
  String expSeveralPaidCaption(int count, String amount);

  /// No description provided for @expYouLent.
  ///
  /// In en, this message translates to:
  /// **'you lent'**
  String get expYouLent;

  /// No description provided for @expYouBorrowed.
  ///
  /// In en, this message translates to:
  /// **'you borrowed'**
  String get expYouBorrowed;

  /// No description provided for @expNotInvolved.
  ///
  /// In en, this message translates to:
  /// **'not involved'**
  String get expNotInvolved;

  /// No description provided for @expNoBalance.
  ///
  /// In en, this message translates to:
  /// **'no balance'**
  String get expNoBalance;

  /// No description provided for @expPaidByLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get expPaidByLabel;

  /// No description provided for @expSplitLabel.
  ///
  /// In en, this message translates to:
  /// **'Split · {kind}'**
  String expSplitLabel(String kind);

  /// No description provided for @expDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get expDetailsLabel;

  /// No description provided for @expAddedBy.
  ///
  /// In en, this message translates to:
  /// **'Added by {name} on {date}'**
  String expAddedBy(String name, String date);

  /// No description provided for @expAddedOn.
  ///
  /// In en, this message translates to:
  /// **'Added on {date}'**
  String expAddedOn(String date);

  /// No description provided for @expEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get expEdit;

  /// No description provided for @expDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete expense'**
  String get expDelete;

  /// No description provided for @expDeleted.
  ///
  /// In en, this message translates to:
  /// **'Expense deleted'**
  String get expDeleted;

  /// No description provided for @expUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get expUndo;

  /// No description provided for @expHistory.
  ///
  /// In en, this message translates to:
  /// **'Edit history'**
  String get expHistory;

  /// No description provided for @expComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get expComments;

  /// No description provided for @expEditedBy.
  ///
  /// In en, this message translates to:
  /// **'Edited by {name} on {date}'**
  String expEditedBy(String name, String date);

  /// No description provided for @expEditedOn.
  ///
  /// In en, this message translates to:
  /// **'Edited on {date}'**
  String expEditedOn(String date);

  /// No description provided for @histTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit history'**
  String get histTitle;

  /// No description provided for @histPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'{from} paid {to}'**
  String histPaymentTitle(String from, String to);

  /// No description provided for @histAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added this'**
  String histAdded(String name);

  /// No description provided for @histEdited.
  ///
  /// In en, this message translates to:
  /// **'{name} edited this'**
  String histEdited(String name);

  /// No description provided for @histDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted this'**
  String histDeleted(String name);

  /// No description provided for @histRestored.
  ///
  /// In en, this message translates to:
  /// **'{name} restored this'**
  String histRestored(String name);

  /// No description provided for @histLostChange.
  ///
  /// In en, this message translates to:
  /// **'Change by {name}'**
  String histLostChange(String name);

  /// No description provided for @histNotApplied.
  ///
  /// In en, this message translates to:
  /// **'Not applied (a newer edit won)'**
  String get histNotApplied;

  /// No description provided for @histFormerMember.
  ///
  /// In en, this message translates to:
  /// **'A former member'**
  String get histFormerMember;

  /// No description provided for @histWhen.
  ///
  /// In en, this message translates to:
  /// **'{date} · {time}'**
  String histWhen(String date, String time);

  /// No description provided for @histFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get histFieldDescription;

  /// No description provided for @histFieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get histFieldAmount;

  /// No description provided for @histFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get histFieldDate;

  /// No description provided for @histFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get histFieldCategory;

  /// No description provided for @histFieldPayers.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get histFieldPayers;

  /// No description provided for @histFieldShares.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get histFieldShares;

  /// No description provided for @histFieldSplitKind.
  ///
  /// In en, this message translates to:
  /// **'Split type'**
  String get histFieldSplitKind;

  /// No description provided for @histFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get histFieldNotes;

  /// No description provided for @histFieldKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get histFieldKind;

  /// No description provided for @histFieldMethod.
  ///
  /// In en, this message translates to:
  /// **'Paid with'**
  String get histFieldMethod;

  /// No description provided for @histFieldFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get histFieldFrom;

  /// No description provided for @histFieldTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get histFieldTo;

  /// No description provided for @histSplitDetailsChanged.
  ///
  /// In en, this message translates to:
  /// **'Split details changed'**
  String get histSplitDetailsChanged;

  /// No description provided for @histReceiptAdded.
  ///
  /// In en, this message translates to:
  /// **'Receipt added'**
  String get histReceiptAdded;

  /// No description provided for @histReceiptRemoved.
  ///
  /// In en, this message translates to:
  /// **'Receipt removed'**
  String get histReceiptRemoved;

  /// No description provided for @histReceiptReplaced.
  ///
  /// In en, this message translates to:
  /// **'Receipt replaced'**
  String get histReceiptReplaced;

  /// No description provided for @histNoValue.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get histNoValue;

  /// No description provided for @histNoVisibleChange.
  ///
  /// In en, this message translates to:
  /// **'Nothing you can see changed'**
  String get histNoVisibleChange;

  /// No description provided for @histKindExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get histKindExpense;

  /// No description provided for @histKindIou.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get histKindIou;

  /// No description provided for @histMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get histMethodCash;

  /// No description provided for @histMethodUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get histMethodUpi;

  /// No description provided for @histMethodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get histMethodBank;

  /// No description provided for @histMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get histMethodOther;

  /// No description provided for @histChangeA11y.
  ///
  /// In en, this message translates to:
  /// **'{field}: {from} to {to}'**
  String histChangeA11y(String field, String from, String to);

  /// No description provided for @histPending.
  ///
  /// In en, this message translates to:
  /// **'Your latest change shows here once it\'s synced.'**
  String get histPending;

  /// No description provided for @histOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'Showing saved history. Connect to see newer changes.'**
  String get histOfflineNote;

  /// No description provided for @histOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'History needs internet'**
  String get histOfflineTitle;

  /// No description provided for @histOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Connect once to load it. After that it stays on this phone.'**
  String get histOfflineBody;

  /// No description provided for @histEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get histEmptyTitle;

  /// No description provided for @histEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Changes show up here once they reach the server.'**
  String get histEmptyBody;

  /// No description provided for @histRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get histRetry;

  /// No description provided for @histNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item isn\'t on this phone'**
  String get histNotFound;

  /// No description provided for @histNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may belong to a group you left.'**
  String get histNotFoundBody;

  /// No description provided for @cmtHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get cmtHint;

  /// No description provided for @cmtSend.
  ///
  /// In en, this message translates to:
  /// **'Send comment'**
  String get cmtSend;

  /// No description provided for @cmtEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get cmtEmptyTitle;

  /// No description provided for @cmtEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation'**
  String get cmtEmptyBody;

  /// No description provided for @cmtDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get cmtDelete;

  /// No description provided for @cmtDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this comment?'**
  String get cmtDeleteTitle;

  /// No description provided for @cmtDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It disappears for everyone in the group.'**
  String get cmtDeleteBody;

  /// No description provided for @cmtDeleted.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted'**
  String get cmtDeleted;

  /// No description provided for @cmtTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep it under {max} characters.'**
  String cmtTooLong(int max);

  /// No description provided for @cmtArchived.
  ///
  /// In en, this message translates to:
  /// **'This group is archived, so comments are read-only.'**
  String get cmtArchived;

  /// No description provided for @cmtA11y.
  ///
  /// In en, this message translates to:
  /// **'{name}, {time}: {body}'**
  String cmtA11y(String name, String time, String body);

  /// No description provided for @cmtOptions.
  ///
  /// In en, this message translates to:
  /// **'Comment options'**
  String get cmtOptions;

  /// No description provided for @delTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted items'**
  String get delTitle;

  /// No description provided for @delSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses and payments deleted in this group. Restoring brings one back for everyone.'**
  String get delSubtitle;

  /// No description provided for @delEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing deleted'**
  String get delEmptyTitle;

  /// No description provided for @delEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Deleted expenses and payments show up here, ready to restore.'**
  String get delEmptyBody;

  /// No description provided for @delBy.
  ///
  /// In en, this message translates to:
  /// **'Deleted by {name} · {date}'**
  String delBy(String name, String date);

  /// No description provided for @delOn.
  ///
  /// In en, this message translates to:
  /// **'Deleted {date}'**
  String delOn(String date);

  /// No description provided for @delRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get delRestored;

  /// No description provided for @delArchivedNote.
  ///
  /// In en, this message translates to:
  /// **'Unarchive the group to restore items.'**
  String get delArchivedNote;

  /// No description provided for @delRestoreA11y.
  ///
  /// In en, this message translates to:
  /// **'Restore {item}'**
  String delRestoreA11y(String item);

  /// No description provided for @expNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'This expense isn\'t here'**
  String get expNotFoundTitle;

  /// No description provided for @expNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted on another phone.'**
  String get expNotFoundBody;

  /// No description provided for @expYouLentAmount.
  ///
  /// In en, this message translates to:
  /// **'You lent {amount}'**
  String expYouLentAmount(String amount);

  /// No description provided for @expYouBorrowedAmount.
  ///
  /// In en, this message translates to:
  /// **'You borrowed {amount}'**
  String expYouBorrowedAmount(String amount);

  /// No description provided for @expNotInvolvedLong.
  ///
  /// In en, this message translates to:
  /// **'You\'re not involved'**
  String get expNotInvolvedLong;

  /// No description provided for @expNoBalanceLong.
  ///
  /// In en, this message translates to:
  /// **'You\'re even on this one'**
  String get expNoBalanceLong;

  /// No description provided for @expDefaultSplitTitle.
  ///
  /// In en, this message translates to:
  /// **'Default split'**
  String get expDefaultSplitTitle;

  /// No description provided for @expDefaultSplitBody.
  ///
  /// In en, this message translates to:
  /// **'New expenses in {group} start with this split. If the members change, they go back to equal.'**
  String expDefaultSplitBody(String group);

  /// No description provided for @expDefaultSplitEqualNote.
  ///
  /// In en, this message translates to:
  /// **'Everyone pays the same share.'**
  String get expDefaultSplitEqualNote;

  /// No description provided for @expDefaultSplitSaved.
  ///
  /// In en, this message translates to:
  /// **'Default split saved'**
  String get expDefaultSplitSaved;

  /// No description provided for @expPickGroup.
  ///
  /// In en, this message translates to:
  /// **'Add to which group?'**
  String get expPickGroup;

  /// No description provided for @expNoGroupFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a group first, then add expenses to it.'**
  String get expNoGroupFirst;

  /// No description provided for @catFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get catFood;

  /// No description provided for @catGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get catGroceries;

  /// No description provided for @catTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get catTravel;

  /// No description provided for @catRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get catRent;

  /// No description provided for @catUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get catUtilities;

  /// No description provided for @catShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get catShopping;

  /// No description provided for @catEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get catEntertainment;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @catFoodDiningOut.
  ///
  /// In en, this message translates to:
  /// **'Dining out'**
  String get catFoodDiningOut;

  /// No description provided for @catFoodTakeaway.
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get catFoodTakeaway;

  /// No description provided for @catFoodSnacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get catFoodSnacks;

  /// No description provided for @catGroceriesGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get catGroceriesGroceries;

  /// No description provided for @catGroceriesHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get catGroceriesHousehold;

  /// No description provided for @catTravelFlights.
  ///
  /// In en, this message translates to:
  /// **'Flights'**
  String get catTravelFlights;

  /// No description provided for @catTravelTrainBus.
  ///
  /// In en, this message translates to:
  /// **'Train & bus'**
  String get catTravelTrainBus;

  /// No description provided for @catTravelCabAuto.
  ///
  /// In en, this message translates to:
  /// **'Cab & auto'**
  String get catTravelCabAuto;

  /// No description provided for @catTravelFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get catTravelFuel;

  /// No description provided for @catTravelHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get catTravelHotel;

  /// No description provided for @catTravelParkingTolls.
  ///
  /// In en, this message translates to:
  /// **'Parking & tolls'**
  String get catTravelParkingTolls;

  /// No description provided for @catRentRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get catRentRent;

  /// No description provided for @catRentMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get catRentMaintenance;

  /// No description provided for @catUtilitiesElectricity.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get catUtilitiesElectricity;

  /// No description provided for @catUtilitiesWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get catUtilitiesWater;

  /// No description provided for @catUtilitiesGas.
  ///
  /// In en, this message translates to:
  /// **'Gas'**
  String get catUtilitiesGas;

  /// No description provided for @catUtilitiesInternetPhone.
  ///
  /// In en, this message translates to:
  /// **'Internet & phone'**
  String get catUtilitiesInternetPhone;

  /// No description provided for @catUtilitiesSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get catUtilitiesSubscriptions;

  /// No description provided for @catShoppingClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get catShoppingClothing;

  /// No description provided for @catShoppingElectronics.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get catShoppingElectronics;

  /// No description provided for @catShoppingGifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get catShoppingGifts;

  /// No description provided for @catShoppingOther.
  ///
  /// In en, this message translates to:
  /// **'Other shopping'**
  String get catShoppingOther;

  /// No description provided for @catEntertainmentMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get catEntertainmentMovies;

  /// No description provided for @catEntertainmentEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get catEntertainmentEvents;

  /// No description provided for @catEntertainmentGames.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get catEntertainmentGames;

  /// No description provided for @catEntertainmentSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get catEntertainmentSports;

  /// No description provided for @catOtherGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get catOtherGeneral;

  /// No description provided for @catOtherMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get catOtherMedical;

  /// No description provided for @catOtherEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get catOtherEducation;

  /// No description provided for @catOtherServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get catOtherServices;

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

  /// Account settings row and screen title (04 §9).
  ///
  /// In en, this message translates to:
  /// **'Sync & storage'**
  String get syncStorage;

  /// No description provided for @syncStorageHint.
  ///
  /// In en, this message translates to:
  /// **'Changes are saved on this phone first, then sent to your groups.'**
  String get syncStorageHint;

  /// No description provided for @syncStateSynced.
  ///
  /// In en, this message translates to:
  /// **'Everything is synced'**
  String get syncStateSynced;

  /// No description provided for @syncStateWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to sync} other{{count} changes waiting to sync}}'**
  String syncStateWaiting(int count);

  /// No description provided for @syncStateOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get syncStateOffline;

  /// No description provided for @syncStateOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Changes stay on this phone and sync when you are back online.'**
  String get syncStateOfflineHint;

  /// No description provided for @syncStateFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change needs attention} other{{count} changes need attention}}'**
  String syncStateFailed(int count);

  /// No description provided for @syncStateError.
  ///
  /// In en, this message translates to:
  /// **'Sync did not finish. It tries again soon.'**
  String get syncStateError;

  /// No description provided for @syncStateSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to sync'**
  String get syncStateSignedOut;

  /// No description provided for @lastSyncLine.
  ///
  /// In en, this message translates to:
  /// **'Last sync {when}'**
  String lastSyncLine(String when);

  /// No description provided for @lastSyncNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get lastSyncNever;

  /// No description provided for @lastSyncJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get lastSyncJustNow;

  /// No description provided for @lastSyncMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String lastSyncMinutes(int minutes);

  /// No description provided for @lastSyncHours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour ago} other{{hours} hours ago}}'**
  String lastSyncHours(int hours);

  /// No description provided for @lastSyncOn.
  ///
  /// In en, this message translates to:
  /// **'on {date}'**
  String lastSyncOn(String date);

  /// No description provided for @syncWaitingLabel.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get syncWaitingLabel;

  /// No description provided for @syncFailedLabel.
  ///
  /// In en, this message translates to:
  /// **'Need attention'**
  String get syncFailedLabel;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncIssuesTitle.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get syncIssuesTitle;

  /// No description provided for @syncIssueEntity.
  ///
  /// In en, this message translates to:
  /// **'{entity, select, group{Group} member{Member} expense{Expense} payment{Payment} comment{Comment} other{Change}}'**
  String syncIssueEntity(String entity);

  /// No description provided for @syncIssueOp.
  ///
  /// In en, this message translates to:
  /// **'{op, select, delete{Delete} restore{Restore} other{Edit}}'**
  String syncIssueOp(String op);

  /// No description provided for @syncIssueTries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Tried once} other{Tried {count} times}}'**
  String syncIssueTries(int count);

  /// No description provided for @syncErrorNotMember.
  ///
  /// In en, this message translates to:
  /// **'You are no longer in this group.'**
  String get syncErrorNotMember;

  /// No description provided for @syncErrorRejected.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept this change.'**
  String get syncErrorRejected;

  /// No description provided for @syncErrorCode.
  ///
  /// In en, this message translates to:
  /// **'Code {code}'**
  String syncErrorCode(String code);

  /// No description provided for @retryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryLabel;

  /// No description provided for @discardLabel.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardLabel;

  /// No description provided for @discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this change?'**
  String get discardTitle;

  /// No description provided for @discardBody.
  ///
  /// In en, this message translates to:
  /// **'It is removed from this phone and the copy on the server comes back.'**
  String get discardBody;

  /// No description provided for @onThisPhone.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get onThisPhone;

  /// No description provided for @exportDebugLog.
  ///
  /// In en, this message translates to:
  /// **'Export debug log'**
  String get exportDebugLog;

  /// No description provided for @debugLogSubject.
  ///
  /// In en, this message translates to:
  /// **'Splitify debug log'**
  String get debugLogSubject;

  /// No description provided for @syncRowSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncRowSynced;

  /// No description provided for @syncRowWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String syncRowWaiting(int count);

  /// No description provided for @syncRowProblems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 problem} other{{count} problems}}'**
  String syncRowProblems(int count);

  /// No description provided for @payersMultipleHint.
  ///
  /// In en, this message translates to:
  /// **'Type what each person paid. Payers don\'t have to be in the split.'**
  String get payersMultipleHint;

  /// No description provided for @payersNone.
  ///
  /// In en, this message translates to:
  /// **'Type at least one amount'**
  String get payersNone;

  /// No description provided for @payersDone.
  ///
  /// In en, this message translates to:
  /// **'{total} covered'**
  String payersDone(String total);

  /// No description provided for @payerAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount {name} paid'**
  String payerAmountLabel(String name);

  /// No description provided for @payersTwo.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String payersTwo(String first, String second);

  /// No description provided for @payersMany.
  ///
  /// In en, this message translates to:
  /// **'{first} and {count, plural, =1{1 other} other{{count} others}}'**
  String payersMany(String first, int count);

  /// No description provided for @payersCaption.
  ///
  /// In en, this message translates to:
  /// **'{names} paid {amount}'**
  String payersCaption(String names, String amount);

  /// No description provided for @loanAction.
  ///
  /// In en, this message translates to:
  /// **'Record a loan'**
  String get loanAction;

  /// No description provided for @loanTitle.
  ///
  /// In en, this message translates to:
  /// **'Record a loan'**
  String get loanTitle;

  /// No description provided for @loanEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit loan'**
  String get loanEditTitle;

  /// No description provided for @loanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Money lent or borrowed, outside any bill. It isn\'t counted as spending.'**
  String get loanSubtitle;

  /// No description provided for @loanILent.
  ///
  /// In en, this message translates to:
  /// **'I lent'**
  String get loanILent;

  /// No description provided for @loanIBorrowed.
  ///
  /// In en, this message translates to:
  /// **'I borrowed'**
  String get loanIBorrowed;

  /// No description provided for @loanToWhom.
  ///
  /// In en, this message translates to:
  /// **'To whom?'**
  String get loanToWhom;

  /// No description provided for @loanFromWhom.
  ///
  /// In en, this message translates to:
  /// **'From whom?'**
  String get loanFromWhom;

  /// No description provided for @loanSentenceLent.
  ///
  /// In en, this message translates to:
  /// **'You lent {name} {amount}'**
  String loanSentenceLent(String name, String amount);

  /// No description provided for @loanSentenceBorrowed.
  ///
  /// In en, this message translates to:
  /// **'{name} lent you {amount}'**
  String loanSentenceBorrowed(String name, String amount);

  /// No description provided for @loanResultLent.
  ///
  /// In en, this message translates to:
  /// **'{name} will owe you {amount}'**
  String loanResultLent(String name, String amount);

  /// No description provided for @loanResultBorrowed.
  ///
  /// In en, this message translates to:
  /// **'You will owe {name} {amount}'**
  String loanResultBorrowed(String name, String amount);

  /// No description provided for @loanPickPerson.
  ///
  /// In en, this message translates to:
  /// **'Choose a person'**
  String get loanPickPerson;

  /// No description provided for @loanNoOthers.
  ///
  /// In en, this message translates to:
  /// **'Add someone to this group first.'**
  String get loanNoOthers;

  /// No description provided for @loanWhatFor.
  ///
  /// In en, this message translates to:
  /// **'What for?'**
  String get loanWhatFor;

  /// No description provided for @loanWhatForHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, e.g. Cab money'**
  String get loanWhatForHint;

  /// No description provided for @loanDefaultDescription.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get loanDefaultDescription;

  /// No description provided for @loanSave.
  ///
  /// In en, this message translates to:
  /// **'Save loan'**
  String get loanSave;

  /// No description provided for @loanSaved.
  ///
  /// In en, this message translates to:
  /// **'Loan saved'**
  String get loanSaved;

  /// No description provided for @loanChip.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get loanChip;

  /// No description provided for @loanCaption.
  ///
  /// In en, this message translates to:
  /// **'{lender} lent {borrower} {amount}'**
  String loanCaption(String lender, String borrower, String amount);

  /// No description provided for @loanLentBy.
  ///
  /// In en, this message translates to:
  /// **'Lent by'**
  String get loanLentBy;

  /// No description provided for @loanBorrowedBy.
  ///
  /// In en, this message translates to:
  /// **'Borrowed by'**
  String get loanBorrowedBy;

  /// No description provided for @loanAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Loan amount'**
  String get loanAmountLabel;

  /// No description provided for @loanNotSpending.
  ///
  /// In en, this message translates to:
  /// **'Loans aren\'t counted in group totals.'**
  String get loanNotSpending;

  /// No description provided for @receiptLabel.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptLabel;

  /// No description provided for @receiptAdd.
  ///
  /// In en, this message translates to:
  /// **'Add receipt photo'**
  String get receiptAdd;

  /// No description provided for @receiptAddHint.
  ///
  /// In en, this message translates to:
  /// **'One photo per expense, shrunk before it\'s uploaded.'**
  String get receiptAddHint;

  /// No description provided for @receiptPhoto.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo'**
  String get receiptPhoto;

  /// No description provided for @receiptRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove the receipt photo?'**
  String get receiptRemoveTitle;

  /// No description provided for @receiptRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the group stops seeing it. Earlier versions stay in the edit history.'**
  String get receiptRemoveBody;

  /// No description provided for @receiptRemoved.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo removed'**
  String get receiptRemoved;

  /// No description provided for @receiptReplaced.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo replaced'**
  String get receiptReplaced;

  /// No description provided for @receiptOnList.
  ///
  /// In en, this message translates to:
  /// **'Has a receipt photo'**
  String get receiptOnList;

  /// No description provided for @photoSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get photoSourceTitle;

  /// No description provided for @photoTake.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get photoTake;

  /// No description provided for @photoChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose from your photos'**
  String get photoChoose;

  /// No description provided for @photoChooseHint.
  ///
  /// In en, this message translates to:
  /// **'Opens the Android photo picker. Splitify only sees the photo you pick.'**
  String get photoChooseHint;

  /// No description provided for @photoReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get photoReplace;

  /// No description provided for @photoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get photoRemove;

  /// No description provided for @photoView.
  ///
  /// In en, this message translates to:
  /// **'Open photo'**
  String get photoView;

  /// No description provided for @photoClose.
  ///
  /// In en, this message translates to:
  /// **'Close photo'**
  String get photoClose;

  /// No description provided for @photoWaiting.
  ///
  /// In en, this message translates to:
  /// **'Uploads when you\'re online'**
  String get photoWaiting;

  /// No description provided for @photoOffline.
  ///
  /// In en, this message translates to:
  /// **'Shows when you\'re online'**
  String get photoOffline;

  /// No description provided for @photoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo not available'**
  String get photoUnavailable;

  /// No description provided for @photoPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t use that photo. Try another one.'**
  String get photoPickFailed;

  /// No description provided for @photoZoomHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch or double-tap to zoom'**
  String get photoZoomHint;

  /// No description provided for @coverLabel.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get coverLabel;

  /// No description provided for @coverGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get coverGenerated;

  /// No description provided for @coverPhotoOption.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get coverPhotoOption;

  /// No description provided for @coverChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get coverChangePhoto;

  /// No description provided for @coverPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Your photo is shrunk and shared with group members only.'**
  String get coverPhotoHint;

  /// No description provided for @coverPhotoSaved.
  ///
  /// In en, this message translates to:
  /// **'Cover photo saved'**
  String get coverPhotoSaved;

  /// No description provided for @loanNameLent.
  ///
  /// In en, this message translates to:
  /// **'{name} lent'**
  String loanNameLent(String name);

  /// No description provided for @loanNameBorrowed.
  ///
  /// In en, this message translates to:
  /// **'{name} borrowed'**
  String loanNameBorrowed(String name);

  /// No description provided for @loanAmountDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get loanAmountDone;
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
