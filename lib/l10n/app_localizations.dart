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
  /// **'Offline · showing what\'s on this phone'**
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

  /// Subtitle of a muted group in notification settings.
  ///
  /// In en, this message translates to:
  /// **'Muted · bell only'**
  String get notifMutedOn;

  /// No description provided for @notifMutedOff.
  ///
  /// In en, this message translates to:
  /// **'Not muted'**
  String get notifMutedOff;

  /// No description provided for @notifMutedEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in any groups yet.'**
  String get notifMutedEmpty;

  /// Settings banner in builds without Firebase (D-020).
  ///
  /// In en, this message translates to:
  /// **'Push notifications aren\'t set up in this build. Everything still shows in the bell.'**
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
  /// **'Free forever · no ads'**
  String get welcomeBadge;

  /// Welcome's main button (white pill with an arrow), opens sign-in.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @welcomeFooter.
  ///
  /// In en, this message translates to:
  /// **'Open source · made in India'**
  String get welcomeFooter;

  /// Short app name beside the mark on the welcome screen (shown in letter-spaced capitals).
  ///
  /// In en, this message translates to:
  /// **'Splitify'**
  String get welcomeBrand;

  /// Two short sentences under the welcome headline, one per line.
  ///
  /// In en, this message translates to:
  /// **'Split bills with friends, settle up with UPI.\nWorks offline, free forever.'**
  String get welcomeSubline;

  /// No description provided for @welcomeFeatureUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI settle-up'**
  String get welcomeFeatureUpi;

  /// No description provided for @welcomeFeatureOffline.
  ///
  /// In en, this message translates to:
  /// **'Works offline'**
  String get welcomeFeatureOffline;

  /// No description provided for @welcomeFeatureNoAds.
  ///
  /// In en, this message translates to:
  /// **'No ads ever'**
  String get welcomeFeatureNoAds;

  /// Before the 'Join a group' link at the bottom of the welcome screen.
  ///
  /// In en, this message translates to:
  /// **'Have an invite?'**
  String get welcomeInvitePrompt;

  /// Sample group name on the welcome screen's product preview (a trip).
  ///
  /// In en, this message translates to:
  /// **'Goa Trip'**
  String get welcomeSampleTrip;

  /// Sample group name on the welcome screen's product preview (a shared flat).
  ///
  /// In en, this message translates to:
  /// **'Flat 4B'**
  String get welcomeSampleHome;

  /// Sample friend on the welcome screen's product preview.
  ///
  /// In en, this message translates to:
  /// **'Asha'**
  String get welcomeSampleAsha;

  /// Sample friend on the welcome screen's product preview.
  ///
  /// In en, this message translates to:
  /// **'Rahul'**
  String get welcomeSampleRahul;

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
  /// **'Active groups · {count}'**
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
  /// **'Use up to 60 characters'**
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

  /// No description provided for @groupFormCover.
  ///
  /// In en, this message translates to:
  /// **'Group cover'**
  String get groupFormCover;

  /// No description provided for @groupFormCoverChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get groupFormCoverChoose;

  /// No description provided for @groupFormPeopleLabel.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get groupFormPeopleLabel;

  /// No description provided for @groupFormPeopleHint.
  ///
  /// In en, this message translates to:
  /// **'Type a name, then Add'**
  String get groupFormPeopleHint;

  /// No description provided for @groupFormAddPerson.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get groupFormAddPerson;

  /// No description provided for @groupFormPeopleNote.
  ///
  /// In en, this message translates to:
  /// **'They don\'t need the app. They can join later with the invite link and claim their spot.'**
  String get groupFormPeopleNote;

  /// No description provided for @groupFormRemovePerson.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String groupFormRemovePerson(String name);

  /// No description provided for @groupFormInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite with a link or QR'**
  String get groupFormInvite;

  /// No description provided for @groupFormInviteNew.
  ///
  /// In en, this message translates to:
  /// **'Saves the group, then shows its link'**
  String get groupFormInviteNew;

  /// No description provided for @groupFormDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this group?'**
  String get groupFormDiscardTitle;

  /// No description provided for @groupFormDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The name and people you typed will be lost.'**
  String get groupFormDiscardBody;

  /// No description provided for @groupFormDiscardEditBody.
  ///
  /// In en, this message translates to:
  /// **'The group stays as it was last saved.'**
  String get groupFormDiscardEditBody;

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
  /// **'Once the group has expenses, you\'ll see who owes whom.'**
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

  /// No description provided for @settingsAddPeople.
  ///
  /// In en, this message translates to:
  /// **'Add people to group'**
  String get settingsAddPeople;

  /// No description provided for @settingsInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite via link or QR'**
  String get settingsInviteLink;

  /// No description provided for @settingsSectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsSectionSettings;

  /// No description provided for @settingsSectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsSectionData;

  /// No description provided for @settingsGroupCaption.
  ///
  /// In en, this message translates to:
  /// **'{type} · {currency}'**
  String settingsGroupCaption(String type, String currency);

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
  /// **'Enter a name (up to 50 characters)'**
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
  /// **'Everyone loses access. You can restore it for 30 days from Account → Deleted groups.'**
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
  /// **'Groups you deleted. Restore one within 30 days.'**
  String get deletedGroupsBody;

  /// No description provided for @deletedGroupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No deleted groups'**
  String get deletedGroupsEmpty;

  /// No description provided for @deletedGroupsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Groups you delete show up here for 30 days.'**
  String get deletedGroupsEmptyBody;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Last day to restore} =1{1 day left} other{{days} days left}}'**
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
  /// **'Friends scan this QR, or type the code under Join on the Groups tab.'**
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

  /// No description provided for @inviteLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get inviteLinkLabel;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

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
  /// **'Paste or type the invite code, or scan the QR a friend shows you.'**
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
  /// **'Too many tries. Wait a minute and try again.'**
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

  /// No description provided for @joinPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get joinPaste;

  /// No description provided for @joinPasteEmpty.
  ///
  /// In en, this message translates to:
  /// **'There is no invite code to paste'**
  String get joinPasteEmpty;

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

  /// No description provided for @friendsSection.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsSection;

  /// No description provided for @friendsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search friends'**
  String get friendsSearchHint;

  /// No description provided for @addFriendExpense.
  ///
  /// In en, this message translates to:
  /// **'Add friend expense'**
  String get addFriendExpense;

  /// No description provided for @friendsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No one called “{query}”'**
  String friendsNoMatch(String query);

  /// No description provided for @friendOwesYou.
  ///
  /// In en, this message translates to:
  /// **'owes you'**
  String get friendOwesYou;

  /// No description provided for @friendYouOwe.
  ///
  /// In en, this message translates to:
  /// **'you owe'**
  String get friendYouOwe;

  /// No description provided for @friendDirectOnly.
  ///
  /// In en, this message translates to:
  /// **'Friend expenses'**
  String get friendDirectOnly;

  /// No description provided for @friendGroupsMore.
  ///
  /// In en, this message translates to:
  /// **'{names} +{count}'**
  String friendGroupsMore(String names, int count);

  /// No description provided for @friendPillOwed.
  ///
  /// In en, this message translates to:
  /// **'{name} owes you {amount}'**
  String friendPillOwed(String name, String amount);

  /// No description provided for @friendPillOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe {name} {amount}'**
  String friendPillOwe(String name, String amount);

  /// No description provided for @friendByGroup.
  ///
  /// In en, this message translates to:
  /// **'By group'**
  String get friendByGroup;

  /// No description provided for @friendSharedItems.
  ///
  /// In en, this message translates to:
  /// **'Shared expenses'**
  String get friendSharedItems;

  /// No description provided for @friendNoItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing shared yet'**
  String get friendNoItemsTitle;

  /// No description provided for @friendNoItemsBody.
  ///
  /// In en, this message translates to:
  /// **'Add an expense with {name} to get started.'**
  String friendNoItemsBody(String name);

  /// No description provided for @friendDirectGroup.
  ///
  /// In en, this message translates to:
  /// **'Just you two'**
  String get friendDirectGroup;

  /// No description provided for @friendItemCaption.
  ///
  /// In en, this message translates to:
  /// **'{group} · {date}'**
  String friendItemCaption(String group, String date);

  /// No description provided for @friendNotFound.
  ///
  /// In en, this message translates to:
  /// **'This friend isn\'t on this phone'**
  String get friendNotFound;

  /// No description provided for @friendSettledSnack.
  ///
  /// In en, this message translates to:
  /// **'You and {name} are settled up'**
  String friendSettledSnack(String name);

  /// No description provided for @friendSettleTitle.
  ///
  /// In en, this message translates to:
  /// **'Settle up with {name}'**
  String friendSettleTitle(String name);

  /// No description provided for @friendInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite {name} to claim their spot'**
  String friendInvite(String name);

  /// No description provided for @friendNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet once to start sharing with {name}. After that it works offline.'**
  String friendNeedsInternet(String name);

  /// No description provided for @friendStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start an expense with {name}. Try again.'**
  String friendStartFailed(String name);

  /// No description provided for @friendGroupSettled.
  ///
  /// In en, this message translates to:
  /// **'settled up'**
  String get friendGroupSettled;

  /// No description provided for @addFriendWho.
  ///
  /// In en, this message translates to:
  /// **'Who with?'**
  String get addFriendWho;

  /// No description provided for @addFriendNew.
  ///
  /// In en, this message translates to:
  /// **'Someone new'**
  String get addFriendNew;

  /// No description provided for @addFriendNewHint.
  ///
  /// In en, this message translates to:
  /// **'They don\'t need the app. Invite them later to claim their spot.'**
  String get addFriendNewHint;

  /// No description provided for @addFriend.
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get addFriend;

  /// No description provided for @addFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a friend'**
  String get addFriendTitle;

  /// No description provided for @addFriendInvite.
  ///
  /// In en, this message translates to:
  /// **'Add and invite with a link'**
  String get addFriendInvite;

  /// No description provided for @addFriendAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String addFriendAdded(String name);

  /// No description provided for @friendRemindPick.
  ///
  /// In en, this message translates to:
  /// **'Remind {name}'**
  String friendRemindPick(String name);

  /// No description provided for @remindAction.
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get remindAction;

  /// No description provided for @addFriendNoFriends.
  ///
  /// In en, this message translates to:
  /// **'No friends yet. Add someone new below.'**
  String get addFriendNoFriends;

  /// No description provided for @simplifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Simplify debts'**
  String get simplifyTitle;

  /// No description provided for @simplifyHelp.
  ///
  /// In en, this message translates to:
  /// **'Fewer payments, same totals. Someone may pay a person they didn\'t share an expense with.'**
  String get simplifyHelp;

  /// No description provided for @simplifyOnDone.
  ///
  /// In en, this message translates to:
  /// **'Simplify debts is on'**
  String get simplifyOnDone;

  /// No description provided for @simplifyOffDone.
  ///
  /// In en, this message translates to:
  /// **'Simplify debts is off'**
  String get simplifyOffDone;

  /// No description provided for @actSimplifyOn.
  ///
  /// In en, this message translates to:
  /// **'{actor} turned on simplify debts'**
  String actSimplifyOn(String actor);

  /// No description provided for @actSimplifyOff.
  ///
  /// In en, this message translates to:
  /// **'{actor} turned off simplify debts'**
  String actSimplifyOff(String actor);

  /// No description provided for @actDefaultSplitChanged.
  ///
  /// In en, this message translates to:
  /// **'{actor} changed the default split'**
  String actDefaultSplitChanged(String actor);

  /// No description provided for @upiPay.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} via UPI'**
  String upiPay(String amount);

  /// No description provided for @upiOtherWays.
  ///
  /// In en, this message translates to:
  /// **'Pay from another app'**
  String get upiOtherWays;

  /// No description provided for @upiRecordInstead.
  ///
  /// In en, this message translates to:
  /// **'Record without UPI'**
  String get upiRecordInstead;

  /// No description provided for @upiPayTo.
  ///
  /// In en, this message translates to:
  /// **'To {name}'**
  String upiPayTo(String name);

  /// No description provided for @upiCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy UPI ID'**
  String get upiCopyId;

  /// No description provided for @upiCopyAmount.
  ///
  /// In en, this message translates to:
  /// **'Copy amount'**
  String get upiCopyAmount;

  /// No description provided for @upiShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show UPI QR'**
  String get upiShowQr;

  /// No description provided for @upiCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get upiCopied;

  /// No description provided for @upiReturnTitle.
  ///
  /// In en, this message translates to:
  /// **'Did the payment go through?'**
  String get upiReturnTitle;

  /// No description provided for @upiReturnBody.
  ///
  /// In en, this message translates to:
  /// **'Your UPI app doesn\'t tell Splitify. Mark it as paid once the money has left your account.'**
  String get upiReturnBody;

  /// No description provided for @upiMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get upiMarkPaid;

  /// No description provided for @upiNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get upiNotYet;

  /// No description provided for @upiNoAppTitle.
  ///
  /// In en, this message translates to:
  /// **'No UPI app found'**
  String get upiNoAppTitle;

  /// No description provided for @upiNoAppBody.
  ///
  /// In en, this message translates to:
  /// **'Pay {name} from any UPI app with the UPI ID or the QR code, then record the payment here.'**
  String upiNoAppBody(String name);

  /// No description provided for @upiQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to pay {name}'**
  String upiQrTitle(String name);

  /// No description provided for @upiQrBody.
  ///
  /// In en, this message translates to:
  /// **'Scan with a UPI app on another phone. Amount {amount}.'**
  String upiQrBody(String amount);

  /// No description provided for @upiFailedHint.
  ///
  /// In en, this message translates to:
  /// **'If your app says the payment failed, copy the UPI ID and amount into it by hand.'**
  String get upiFailedHint;

  /// No description provided for @upiNote.
  ///
  /// In en, this message translates to:
  /// **'Splitify: {group}'**
  String upiNote(String group);

  /// No description provided for @upiIdLine.
  ///
  /// In en, this message translates to:
  /// **'UPI ID {vpa}'**
  String upiIdLine(String vpa);

  /// No description provided for @celebrationSettledWith.
  ///
  /// In en, this message translates to:
  /// **'You and {name} are square.'**
  String celebrationSettledWith(String name);

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
  /// **'You are owed and you owe here'**
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
  /// **'paid {paid} · share {share}'**
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

  /// No description provided for @totExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get totExportCsv;

  /// No description provided for @insTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insTitle;

  /// No description provided for @insSpendingIn.
  ///
  /// In en, this message translates to:
  /// **'Spending in {currency}'**
  String insSpendingIn(String currency);

  /// No description provided for @insModeGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get insModeGroup;

  /// No description provided for @insModeMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get insModeMe;

  /// No description provided for @insModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Show spending of'**
  String get insModeLabel;

  /// No description provided for @insAllGroups.
  ///
  /// In en, this message translates to:
  /// **'All groups and friends'**
  String get insAllGroups;

  /// No description provided for @insAllGroupsCaption.
  ///
  /// In en, this message translates to:
  /// **'Your share everywhere'**
  String get insAllGroupsCaption;

  /// No description provided for @insPickGroup.
  ///
  /// In en, this message translates to:
  /// **'Choose a group'**
  String get insPickGroup;

  /// No description provided for @insPickerCaptionGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get insPickerCaptionGroup;

  /// No description provided for @insPickerCaptionMe.
  ///
  /// In en, this message translates to:
  /// **'Your share in'**
  String get insPickerCaptionMe;

  /// No description provided for @insPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Change group'**
  String get insPickerHint;

  /// No description provided for @insArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get insArchived;

  /// No description provided for @insByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get insByCategory;

  /// No description provided for @insAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get insAllTime;

  /// No description provided for @insByMonth.
  ///
  /// In en, this message translates to:
  /// **'By month'**
  String get insByMonth;

  /// No description provided for @insLast12Months.
  ///
  /// In en, this message translates to:
  /// **'Last 12 months'**
  String get insLast12Months;

  /// No description provided for @insTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get insTotalSpent;

  /// No description provided for @insYourShare.
  ///
  /// In en, this message translates to:
  /// **'Your share'**
  String get insYourShare;

  /// No description provided for @insPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String insPercent(int percent);

  /// No description provided for @insPercentSmall.
  ///
  /// In en, this message translates to:
  /// **'<1%'**
  String get insPercentSmall;

  /// No description provided for @insAmountShare.
  ///
  /// In en, this message translates to:
  /// **'{amount} · {percent}'**
  String insAmountShare(String amount, String percent);

  /// No description provided for @insCategoryOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{percent} of the total'**
  String insCategoryOfTotal(String percent);

  /// No description provided for @insDonutLabel.
  ///
  /// In en, this message translates to:
  /// **'Spending by category: {parts}'**
  String insDonutLabel(String parts);

  /// No description provided for @insDonutPart.
  ///
  /// In en, this message translates to:
  /// **'{name} {amount}, {percent}'**
  String insDonutPart(String name, String amount, String percent);

  /// No description provided for @insMonthBar.
  ///
  /// In en, this message translates to:
  /// **'{month}: {amount}'**
  String insMonthBar(String month, String amount);

  /// No description provided for @insYearTotal.
  ///
  /// In en, this message translates to:
  /// **'12-month total {amount}'**
  String insYearTotal(String amount);

  /// No description provided for @insMonthHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a bar to see that month.'**
  String get insMonthHint;

  /// No description provided for @insOneMonthHint.
  ///
  /// In en, this message translates to:
  /// **'Only one month so far. More bars fill in as you add expenses in other months.'**
  String get insOneMonthHint;

  /// No description provided for @insNoRecentMonths.
  ///
  /// In en, this message translates to:
  /// **'Nothing spent in the last 12 months.'**
  String get insNoRecentMonths;

  /// No description provided for @insUnconverted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense in another currency is left out. Convert it to {currency} on its page to count it.} other{{count} expenses in other currencies are left out. Convert them to {currency} on their pages to count them.}}'**
  String insUnconverted(int count, String currency);

  /// No description provided for @insEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing spent yet'**
  String get insEmptyTitle;

  /// No description provided for @insEmptyGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Expenses in {group} show up here by category and month.'**
  String insEmptyGroupBody(String group);

  /// No description provided for @insEmptyMeBody.
  ///
  /// In en, this message translates to:
  /// **'Your share of expenses shows up here by category and month.'**
  String get insEmptyMeBody;

  /// No description provided for @insNoGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get insNoGroupsTitle;

  /// No description provided for @insNoGroupsBody.
  ///
  /// In en, this message translates to:
  /// **'Create or join a group and add expenses to see where the money goes.'**
  String get insNoGroupsBody;

  /// No description provided for @insConvertTitle.
  ///
  /// In en, this message translates to:
  /// **'Convert to see charts'**
  String get insConvertTitle;

  /// No description provided for @insConvertBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense is in another currency. Convert it to {currency} on its page to see it here.} other{{count} expenses are in other currencies. Convert them to {currency} on their pages to see them here.}}'**
  String insConvertBody(int count, String currency);

  /// No description provided for @insLoadError.
  ///
  /// In en, this message translates to:
  /// **'Charts could not be loaded'**
  String get insLoadError;

  /// No description provided for @exportSubject.
  ///
  /// In en, this message translates to:
  /// **'{group} expenses (Splitify)'**
  String exportSubject(String group);

  /// No description provided for @exportEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to export yet. Add an expense first.'**
  String get exportEmpty;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export. Try again.'**
  String get exportFailed;

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
  /// **'Nothing is owed here right now. You can still record it.'**
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
  /// **'Use up to {max} characters'**
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
  /// **'Payment · {date}'**
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

  /// No description provided for @moneyInLabel.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get moneyInLabel;

  /// No description provided for @settleRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record a payment'**
  String get settleRecordTitle;

  /// No description provided for @settleRecordCash.
  ///
  /// In en, this message translates to:
  /// **'Record cash payment'**
  String get settleRecordCash;

  /// No description provided for @settleRecordUpi.
  ///
  /// In en, this message translates to:
  /// **'Record UPI payment'**
  String get settleRecordUpi;

  /// No description provided for @settleRecordBank.
  ///
  /// In en, this message translates to:
  /// **'Record bank payment'**
  String get settleRecordBank;

  /// No description provided for @settlePayUpi.
  ///
  /// In en, this message translates to:
  /// **'Pay via UPI'**
  String get settlePayUpi;

  /// No description provided for @settleMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'How was it paid?'**
  String get settleMethodTitle;

  /// No description provided for @settleToolMethod.
  ///
  /// In en, this message translates to:
  /// **'Method: {method}'**
  String settleToolMethod(String method);

  /// No description provided for @settleToolNoteAdded.
  ///
  /// In en, this message translates to:
  /// **'Note added'**
  String get settleToolNoteAdded;

  /// No description provided for @settleSummaryOwed.
  ///
  /// In en, this message translates to:
  /// **'{owed} owed'**
  String settleSummaryOwed(String owed);

  /// No description provided for @settleSummaryAll.
  ///
  /// In en, this message translates to:
  /// **'Settles all of {owed}'**
  String settleSummaryAll(String owed);

  /// No description provided for @settleSummaryPart.
  ///
  /// In en, this message translates to:
  /// **'Part of the {owed} owed'**
  String settleSummaryPart(String owed);

  /// No description provided for @settleSummaryLeft.
  ///
  /// In en, this message translates to:
  /// **'{left} left after this'**
  String settleSummaryLeft(String left);

  /// No description provided for @settleSummaryOver.
  ///
  /// In en, this message translates to:
  /// **'More than the {owed} owed'**
  String settleSummaryOver(String owed);

  /// No description provided for @settleSummaryExtra.
  ///
  /// In en, this message translates to:
  /// **'{extra} more than owed'**
  String settleSummaryExtra(String extra);

  /// No description provided for @settleNothingOwed.
  ///
  /// In en, this message translates to:
  /// **'Nothing owed right now'**
  String get settleNothingOwed;

  /// No description provided for @settleNothingOwedSub.
  ///
  /// In en, this message translates to:
  /// **'You can still record a payment.'**
  String get settleNothingOwedSub;

  /// No description provided for @settleDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this payment?'**
  String get settleDiscardTitle;

  /// No description provided for @settleDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The amount and note you typed will be lost.'**
  String get settleDiscardBody;

  /// No description provided for @settleDiscardEditBody.
  ///
  /// In en, this message translates to:
  /// **'The payment stays as it was last saved.'**
  String get settleDiscardEditBody;

  /// No description provided for @settlePickHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a balance to settle.'**
  String get settlePickHint;

  /// No description provided for @settlePickYouOwe.
  ///
  /// In en, this message translates to:
  /// **'you owe {amount}'**
  String settlePickYouOwe(String amount);

  /// No description provided for @settlePickOwesYou.
  ///
  /// In en, this message translates to:
  /// **'owes you {amount}'**
  String settlePickOwesYou(String amount);

  /// No description provided for @settlePickOwes.
  ///
  /// In en, this message translates to:
  /// **'owes {name} {amount}'**
  String settlePickOwes(String name, String amount);

  /// No description provided for @loanDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this loan?'**
  String get loanDiscardTitle;

  /// No description provided for @loanDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The amount you typed will be lost.'**
  String get loanDiscardBody;

  /// No description provided for @loanDiscardEditBody.
  ///
  /// In en, this message translates to:
  /// **'The loan stays as it was last saved.'**
  String get loanDiscardEditBody;

  /// No description provided for @loanWhoTitle.
  ///
  /// In en, this message translates to:
  /// **'Who lent whom?'**
  String get loanWhoTitle;

  /// No description provided for @loanWhoHint.
  ///
  /// In en, this message translates to:
  /// **'Change who lent and who borrowed'**
  String get loanWhoHint;

  /// No description provided for @loanPillLent.
  ///
  /// In en, this message translates to:
  /// **'You lent {name}'**
  String loanPillLent(String name);

  /// No description provided for @loanPillBorrowed.
  ///
  /// In en, this message translates to:
  /// **'{name} lent you'**
  String loanPillBorrowed(String name);

  /// No description provided for @loanPillOthers.
  ///
  /// In en, this message translates to:
  /// **'{lender} lent {borrower}'**
  String loanPillOthers(String lender, String borrower);

  /// No description provided for @loanPillNoAmount.
  ///
  /// In en, this message translates to:
  /// **'Type the amount'**
  String get loanPillNoAmount;

  /// No description provided for @loanResultOthers.
  ///
  /// In en, this message translates to:
  /// **'{borrower} will owe {lender} {amount}'**
  String loanResultOthers(String borrower, String lender, String amount);

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
  /// **'{actor} unarchived the group'**
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

  /// No description provided for @actRecurringCreatedNamed.
  ///
  /// In en, this message translates to:
  /// **'{actor} set “{description}” to repeat'**
  String actRecurringCreatedNamed(String actor, String description);

  /// No description provided for @actRecurringUpdated.
  ///
  /// In en, this message translates to:
  /// **'{actor} changed a recurring bill'**
  String actRecurringUpdated(String actor);

  /// No description provided for @actRecurringUpdatedNamed.
  ///
  /// In en, this message translates to:
  /// **'{actor} changed how “{description}” repeats'**
  String actRecurringUpdatedNamed(String actor, String description);

  /// No description provided for @actRecurringStopped.
  ///
  /// In en, this message translates to:
  /// **'{actor} stopped a recurring bill'**
  String actRecurringStopped(String actor);

  /// No description provided for @actRecurringStoppedNamed.
  ///
  /// In en, this message translates to:
  /// **'{actor} stopped repeating “{description}”'**
  String actRecurringStoppedNamed(String actor, String description);

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
  /// **'{count, plural, =1{1 person owes you} other{{count} people owe you}}'**
  String homePeopleOweYou(int count);

  /// No description provided for @homeYouOwePeople.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{you owe 1 person} other{you owe {count} people}}'**
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

  /// No description provided for @settingsNoUpi.
  ///
  /// In en, this message translates to:
  /// **'No UPI ID yet'**
  String get settingsNoUpi;

  /// No description provided for @settingsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get settingsEdit;

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

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'split bills,\nfree forever.'**
  String get aboutHeroTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'A free, open-source app for splitting costs with friends and flatmates, on trips and at home. No ads, no limits, no paywalls.'**
  String get aboutTagline;

  /// No description provided for @aboutSectionProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get aboutSectionProject;

  /// No description provided for @aboutSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get aboutSourceCode;

  /// No description provided for @aboutSourceValue.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get aboutSourceValue;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacy;

  /// No description provided for @aboutReport.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get aboutReport;

  /// No description provided for @aboutLicencesRow.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutLicencesRow;

  /// No description provided for @aboutSectionCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get aboutSectionCredits;

  /// No description provided for @aboutCreditFonts.
  ///
  /// In en, this message translates to:
  /// **'Instrument Serif and Inter fonts, SIL Open Font License'**
  String get aboutCreditFonts;

  /// No description provided for @aboutCreditIcons.
  ///
  /// In en, this message translates to:
  /// **'Phosphor icons, MIT licence'**
  String get aboutCreditIcons;

  /// No description provided for @aboutCreditRates.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates from Frankfurter (European Central Bank data)'**
  String get aboutCreditRates;

  /// No description provided for @aboutCopyright.
  ///
  /// In en, this message translates to:
  /// **'MIT licence · © Unizoy'**
  String get aboutCopyright;

  /// No description provided for @aboutLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link: {url}'**
  String aboutLinkFailed(String url);

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
  /// **'Add a description'**
  String get expDescriptionMissing;

  /// No description provided for @expDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use up to 120 characters'**
  String get expDescriptionTooLong;

  /// No description provided for @expAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expAddTitle;

  /// No description provided for @expWithLabel.
  ///
  /// In en, this message translates to:
  /// **'With you and'**
  String get expWithLabel;

  /// No description provided for @expWithChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose group or friend'**
  String get expWithChoose;

  /// No description provided for @expWithChange.
  ///
  /// In en, this message translates to:
  /// **'Change group or friend'**
  String get expWithChange;

  /// No description provided for @expWithMissing.
  ///
  /// In en, this message translates to:
  /// **'Choose who this is with'**
  String get expWithMissing;

  /// No description provided for @expWithChooseFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a group or friend first'**
  String get expWithChooseFirst;

  /// No description provided for @expWithPickTitle.
  ///
  /// In en, this message translates to:
  /// **'With you and…'**
  String get expWithPickTitle;

  /// No description provided for @expWithSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search groups and friends'**
  String get expWithSearchHint;

  /// No description provided for @expWithRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get expWithRecent;

  /// No description provided for @expWithGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups and friends'**
  String get expWithGroups;

  /// No description provided for @expWithFriends.
  ///
  /// In en, this message translates to:
  /// **'More friends'**
  String get expWithFriends;

  /// No description provided for @expWithFriendLabel.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get expWithFriendLabel;

  /// No description provided for @expWithAddFriend.
  ///
  /// In en, this message translates to:
  /// **'Add “{name}” as a friend'**
  String expWithAddFriend(String name);

  /// No description provided for @expWithAddFriendHint.
  ///
  /// In en, this message translates to:
  /// **'No account needed; they can join later'**
  String get expWithAddFriendHint;

  /// No description provided for @expWithNothingYet.
  ///
  /// In en, this message translates to:
  /// **'No groups or friends yet. Type a name to add a friend.'**
  String get expWithNothingYet;

  /// No description provided for @expAmountMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get expAmountMissing;

  /// No description provided for @expPaidSplitTitle.
  ///
  /// In en, this message translates to:
  /// **'Paid by and split'**
  String get expPaidSplitTitle;

  /// No description provided for @expPaidSplitHint.
  ///
  /// In en, this message translates to:
  /// **'Change who paid and how it\'s split'**
  String get expPaidSplitHint;

  /// No description provided for @expPillPaidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by {name}'**
  String expPillPaidBy(String name);

  /// No description provided for @expPillPeoplePaid.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Several people paid} =1{1 person paid} other{{count} people paid}}'**
  String expPillPeoplePaid(int count);

  /// No description provided for @expPillSummary.
  ///
  /// In en, this message translates to:
  /// **'{paid} · {how}'**
  String expPillSummary(String paid, String how);

  /// No description provided for @expPillSplitEqual.
  ///
  /// In en, this message translates to:
  /// **'split equally'**
  String get expPillSplitEqual;

  /// No description provided for @expPillSplitExact.
  ///
  /// In en, this message translates to:
  /// **'split exactly'**
  String get expPillSplitExact;

  /// No description provided for @expPillSplitPercent.
  ///
  /// In en, this message translates to:
  /// **'split by percentages'**
  String get expPillSplitPercent;

  /// No description provided for @expPillSplitShares.
  ///
  /// In en, this message translates to:
  /// **'split by shares'**
  String get expPillSplitShares;

  /// No description provided for @expPillSplitAdjust.
  ///
  /// In en, this message translates to:
  /// **'split with adjustments'**
  String get expPillSplitAdjust;

  /// No description provided for @expSplitSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get expSplitSectionLabel;

  /// No description provided for @expDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this expense?'**
  String get expDiscardTitle;

  /// No description provided for @expDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The amount and details you typed will be lost.'**
  String get expDiscardBody;

  /// No description provided for @expDiscardEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard your changes?'**
  String get expDiscardEditTitle;

  /// No description provided for @expDiscardEditBody.
  ///
  /// In en, this message translates to:
  /// **'The expense stays as it was last saved.'**
  String get expDiscardEditBody;

  /// No description provided for @expToolDate.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String expToolDate(String date);

  /// No description provided for @expToolFirstDate.
  ///
  /// In en, this message translates to:
  /// **'First date: {date}'**
  String expToolFirstDate(String date);

  /// No description provided for @expToolNotesAdded.
  ///
  /// In en, this message translates to:
  /// **'Notes added'**
  String get expToolNotesAdded;

  /// No description provided for @expToolReceiptAdded.
  ///
  /// In en, this message translates to:
  /// **'Receipt added'**
  String get expToolReceiptAdded;

  /// No description provided for @expCategoryPick.
  ///
  /// In en, this message translates to:
  /// **'Pick a category'**
  String get expCategoryPick;

  /// No description provided for @expCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency {code}'**
  String expCurrencyLabel(String code);

  /// No description provided for @curPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get curPickerTitle;

  /// No description provided for @curSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search currencies'**
  String get curSearchLabel;

  /// No description provided for @curSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Code or name'**
  String get curSearchHint;

  /// No description provided for @curGroupSection.
  ///
  /// In en, this message translates to:
  /// **'Group currency'**
  String get curGroupSection;

  /// No description provided for @curRecentSection.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get curRecentSection;

  /// No description provided for @curAllSection.
  ///
  /// In en, this message translates to:
  /// **'All currencies'**
  String get curAllSection;

  /// No description provided for @curNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No currency matches “{query}”'**
  String curNoMatch(String query);

  /// No description provided for @curRowLabel.
  ///
  /// In en, this message translates to:
  /// **'{name}, {code}'**
  String curRowLabel(String name, String code);

  /// No description provided for @curSelected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get curSelected;

  /// No description provided for @fxConvertTo.
  ///
  /// In en, this message translates to:
  /// **'Convert to {code}'**
  String fxConvertTo(String code);

  /// No description provided for @fxInCurrency.
  ///
  /// In en, this message translates to:
  /// **'In {code}'**
  String fxInCurrency(String code);

  /// No description provided for @fxRateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Rate for 1 {from}'**
  String fxRateFieldLabel(String from);

  /// No description provided for @fxRateNeeded.
  ///
  /// In en, this message translates to:
  /// **'Rate needed'**
  String get fxRateNeeded;

  /// No description provided for @fxRateHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 83.12'**
  String get fxRateHint;

  /// No description provided for @fxRateLine.
  ///
  /// In en, this message translates to:
  /// **'1 {from} = {rate} {to}'**
  String fxRateLine(String from, String rate, String to);

  /// No description provided for @fxSourceFrankfurter.
  ///
  /// In en, this message translates to:
  /// **'Frankfurter · {date}'**
  String fxSourceFrankfurter(String date);

  /// No description provided for @fxSourceFallback.
  ///
  /// In en, this message translates to:
  /// **'Frankfurter · {date} (latest before {asked})'**
  String fxSourceFallback(String date, String asked);

  /// No description provided for @fxSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Rate you typed · {date}'**
  String fxSourceManual(String date);

  /// No description provided for @fxNoRateUnlisted.
  ///
  /// In en, this message translates to:
  /// **'{code} has no published rate. Type the rate.'**
  String fxNoRateUnlisted(String code);

  /// No description provided for @fxNoRateMissing.
  ///
  /// In en, this message translates to:
  /// **'No saved rate for {date} on this phone. Type the rate, or connect to the internet.'**
  String fxNoRateMissing(String date);

  /// No description provided for @fxReferenceNote.
  ///
  /// In en, this message translates to:
  /// **'Reference rates from central banks, not your bank\'s rate.'**
  String get fxReferenceNote;

  /// No description provided for @fxRateError.
  ///
  /// In en, this message translates to:
  /// **'Enter a rate above 0 with up to 10 decimals'**
  String get fxRateError;

  /// No description provided for @fxTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The converted amount is too large'**
  String get fxTooLarge;

  /// No description provided for @fxUseAuto.
  ///
  /// In en, this message translates to:
  /// **'Use Frankfurter rate'**
  String get fxUseAuto;

  /// No description provided for @fxSave.
  ///
  /// In en, this message translates to:
  /// **'Save conversion'**
  String get fxSave;

  /// No description provided for @fxRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove conversion'**
  String get fxRemove;

  /// No description provided for @fxSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Conversion saved'**
  String get fxSavedSnack;

  /// No description provided for @fxRemovedSnack.
  ///
  /// In en, this message translates to:
  /// **'Conversion removed'**
  String get fxRemovedSnack;

  /// No description provided for @fxApprox.
  ///
  /// In en, this message translates to:
  /// **'≈ {amount}'**
  String fxApprox(String amount);

  /// No description provided for @fxNotPossible.
  ///
  /// In en, this message translates to:
  /// **'This record is already in the group\'s currency.'**
  String get fxNotPossible;

  /// No description provided for @fxViewByCurrency.
  ///
  /// In en, this message translates to:
  /// **'By currency'**
  String get fxViewByCurrency;

  /// No description provided for @fxViewInMain.
  ///
  /// In en, this message translates to:
  /// **'In {code}'**
  String fxViewInMain(String code);

  /// No description provided for @fxViewLabel.
  ///
  /// In en, this message translates to:
  /// **'Show balances'**
  String get fxViewLabel;

  /// No description provided for @fxMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record needs a rate} other{{count} records need a rate}}'**
  String fxMissingTitle(int count);

  /// No description provided for @fxMissingBody.
  ///
  /// In en, this message translates to:
  /// **'Balances in {code} use the rate saved with each record, so these need a rate first.'**
  String fxMissingBody(String code);

  /// No description provided for @fxConvertAll.
  ///
  /// In en, this message translates to:
  /// **'Convert all at each date\'s rate'**
  String get fxConvertAll;

  /// No description provided for @fxConvertedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing converted} =1{1 converted} other{{count} converted}}'**
  String fxConvertedCount(int count);

  /// No description provided for @fxNeedRateCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 needs a rate you type} other{{count} need a rate you type}}'**
  String fxNeedRateCount(int count);

  /// No description provided for @fxConvertedNote.
  ///
  /// In en, this message translates to:
  /// **'Each record is counted at the rate saved with it.'**
  String get fxConvertedNote;

  /// No description provided for @fxSectionInMain.
  ///
  /// In en, this message translates to:
  /// **'Everything in {code}'**
  String fxSectionInMain(String code);

  /// No description provided for @fxSimplifyInMain.
  ///
  /// In en, this message translates to:
  /// **'Simplify in {code}'**
  String fxSimplifyInMain(String code);

  /// No description provided for @fxCombineError.
  ///
  /// In en, this message translates to:
  /// **'These records can\'t be combined yet. Check their conversions.'**
  String get fxCombineError;

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

  /// No description provided for @expMultiplePeople.
  ///
  /// In en, this message translates to:
  /// **'Multiple people'**
  String get expMultiplePeople;

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
  /// **'{count, plural, =1{1 person} other{{count} people}} · {amount} each'**
  String expFooterEqual(int count, String amount);

  /// No description provided for @expFooterPeople.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String expFooterPeople(int count);

  /// No description provided for @expFooterLeft.
  ///
  /// In en, this message translates to:
  /// **'{sum} of {total} · {left} left'**
  String expFooterLeft(String sum, String total, String left);

  /// No description provided for @expFooterOver.
  ///
  /// In en, this message translates to:
  /// **'{sum} of {total} · {over} over'**
  String expFooterOver(String sum, String total, String over);

  /// No description provided for @expFooterDone.
  ///
  /// In en, this message translates to:
  /// **'{total} · done'**
  String expFooterDone(String total);

  /// No description provided for @expFooterPercentLeft.
  ///
  /// In en, this message translates to:
  /// **'{sum}% of 100% · {left}% left'**
  String expFooterPercentLeft(String sum, String left);

  /// No description provided for @expFooterPercentOver.
  ///
  /// In en, this message translates to:
  /// **'{sum}% of 100% · {over}% over'**
  String expFooterPercentOver(String sum, String over);

  /// No description provided for @expFooterPercentDone.
  ///
  /// In en, this message translates to:
  /// **'100% · done'**
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

  /// No description provided for @expCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expCategoryLabel;

  /// Tiny tag beside a category that was picked from the description (auto-category). Keep it one short word.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get expCategoryAuto;

  /// Screen-reader label of the category chip under the description.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}'**
  String expCategoryHintLabel(String category);

  /// Screen-reader label of the category chip when the category was suggested from the description.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}, picked from the description'**
  String expCategoryAutoLabel(String category);

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
  /// **'Use up to 1,000 characters'**
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

  /// No description provided for @expYouLower.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get expYouLower;

  /// No description provided for @expOwes.
  ///
  /// In en, this message translates to:
  /// **'share {amount}'**
  String expOwes(String amount);

  /// No description provided for @expOwesNothing.
  ///
  /// In en, this message translates to:
  /// **'no share'**
  String get expOwesNothing;

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
  /// **'Split · {kind}'**
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
  /// **'{name}\'s edit'**
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
  /// **'{date} · {time}'**
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
  /// **'Changes show up here once they\'re synced.'**
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
  /// **'Use up to {max} characters'**
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
  /// **'Deleted by {name} · {date}'**
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
  /// **'New expenses in {group} start with this split. If the members change, it goes back to equal.'**
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
  /// **'Use Google or a one-time code sent by email. The same email always opens the same account.'**
  String get signInSubtitle;

  /// Sign-in subtitle when the user came from an invite (Have an invite? / invite link).
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google or an email code, then we open your invite.'**
  String get signInToJoin;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @googleSoon.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in isn\'t set up in this build. Use your email instead.'**
  String get googleSoon;

  /// No description provided for @googleNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Not set up in this build'**
  String get googleNotSetUp;

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
  /// **'Enter the {digits}-digit code'**
  String codeTitle(int digits);

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent it to {email}. It works for 10 minutes.'**
  String codeSentTo(String email);

  /// No description provided for @codeBoxes.
  ///
  /// In en, this message translates to:
  /// **'{digits}-digit code, {count} of {digits} entered'**
  String codeBoxes(int count, int digits);

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds} s'**
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

  /// No description provided for @profileAddUpi.
  ///
  /// In en, this message translates to:
  /// **'Add a UPI ID (optional)'**
  String get profileAddUpi;

  /// No description provided for @profilePhotoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change your photo'**
  String get profilePhotoTooltip;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @authErrorInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code is wrong or has expired. Check your newest email, or tap Resend code.'**
  String get authErrorInvalidCode;

  /// No description provided for @authErrorExpiredCode.
  ///
  /// In en, this message translates to:
  /// **'This code has expired or is not right. Request a new code.'**
  String get authErrorExpiredCode;

  /// No description provided for @authErrorTooManyTries.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Request a new code.'**
  String get authErrorTooManyTries;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter an email like name@example.com'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Connect to the internet to sign in.'**
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
  /// **'Enter your name (up to 50 characters)'**
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
  /// **'Type “DELETE” to confirm'**
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
  /// **'Sync didn\'t finish. Splitify will try again soon.'**
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
  /// **'{entity, select, group{Group} member{Member} expense{Expense} payment{Payment} comment{Comment} recurring{Repeating expense} other{Change}}'**
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

  /// One-time snackbar after a push where a local edit lost to a newer server edit (04 §3).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Someone else\'s newer edit was kept. Your version is in the edit history.} other{Newer edits by others were kept for {count} changes. Your versions are in the edit history.}}'**
  String syncSuperseded(int count);

  /// Group expense list: loads the next page of older records (S-167).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 older} other{Show {count} older}}'**
  String expShowOlder(int count);

  /// Sync issue card: opens the refused record so the person can fix it.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get syncIssueOpen;

  /// No description provided for @syncUploadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get syncUploadsTitle;

  /// No description provided for @syncUploadKind.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, receipt{Receipt photo} cover{Group cover} other{Photo}}'**
  String syncUploadKind(String kind);

  /// No description provided for @syncUploadWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to upload'**
  String get syncUploadWaiting;

  /// No description provided for @syncUploadRetrying.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Upload failed once, trying again} other{Upload failed {count} times, trying again}}'**
  String syncUploadRetrying(int count);

  /// No description provided for @syncUploadSkipped.
  ///
  /// In en, this message translates to:
  /// **'Upload stopped after {count} tries'**
  String syncUploadSkipped(int count);

  /// No description provided for @syncUploadsWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String syncUploadsWaiting(int count);

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

  /// No description provided for @repeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatLabel;

  /// No description provided for @repeatNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get repeatNever;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get repeatWeekly;

  /// No description provided for @repeatFortnightly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get repeatFortnightly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get repeatMonthly;

  /// No description provided for @repeatYearly.
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get repeatYearly;

  /// No description provided for @repeatEndsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get repeatEndsLabel;

  /// No description provided for @repeatNoEnd.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get repeatNoEnd;

  /// No description provided for @repeatUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String repeatUntil(String date);

  /// No description provided for @repeatPickEnd.
  ///
  /// In en, this message translates to:
  /// **'Pick an end date'**
  String get repeatPickEnd;

  /// No description provided for @repeatEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end date can\'t be before {date}'**
  String repeatEndBeforeStart(String date);

  /// No description provided for @repeatNextHint.
  ///
  /// In en, this message translates to:
  /// **'A copy is added automatically on each date. First copy: {date}.'**
  String repeatNextHint(String date);

  /// No description provided for @repeatNoCopiesHint.
  ///
  /// In en, this message translates to:
  /// **'No copies: the end date is before the first one.'**
  String get repeatNoCopiesHint;

  /// No description provided for @recurringChip.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get recurringChip;

  /// No description provided for @recurringRowLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get recurringRowLabel;

  /// No description provided for @recurringNext.
  ///
  /// In en, this message translates to:
  /// **'Next copy on {date}'**
  String recurringNext(String date);

  /// No description provided for @recurringEndsOn.
  ///
  /// In en, this message translates to:
  /// **'Ends on {date}'**
  String recurringEndsOn(String date);

  /// No description provided for @recurringNoEnd.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get recurringNoEnd;

  /// No description provided for @recurringFinished.
  ///
  /// In en, this message translates to:
  /// **'No more copies'**
  String get recurringFinished;

  /// No description provided for @recurringStoppedValue.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get recurringStoppedValue;

  /// No description provided for @recurringStoppedLine.
  ///
  /// In en, this message translates to:
  /// **'Stopped repeating. Copies already added stay.'**
  String get recurringStoppedLine;

  /// No description provided for @recurringCopyLine.
  ///
  /// In en, this message translates to:
  /// **'Added automatically from a repeating expense'**
  String get recurringCopyLine;

  /// No description provided for @recurringEditFuture.
  ///
  /// In en, this message translates to:
  /// **'Edit future copies'**
  String get recurringEditFuture;

  /// No description provided for @recurringStop.
  ///
  /// In en, this message translates to:
  /// **'Stop repeating'**
  String get recurringStop;

  /// No description provided for @recurringStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop repeating “{description}”?'**
  String recurringStopTitle(String description);

  /// No description provided for @recurringStopBody.
  ///
  /// In en, this message translates to:
  /// **'No more copies will be added. Copies already added stay as they are.'**
  String get recurringStopBody;

  /// No description provided for @recurringStopKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep repeating'**
  String get recurringStopKeep;

  /// No description provided for @recurringStoppedSnack.
  ///
  /// In en, this message translates to:
  /// **'Stopped repeating'**
  String get recurringStoppedSnack;

  /// No description provided for @recurringResume.
  ///
  /// In en, this message translates to:
  /// **'Repeat again'**
  String get recurringResume;

  /// No description provided for @recurringResumedSnack.
  ///
  /// In en, this message translates to:
  /// **'Repeats again from today'**
  String get recurringResumedSnack;

  /// No description provided for @recurringEditPill.
  ///
  /// In en, this message translates to:
  /// **'Future copies · {group}'**
  String recurringEditPill(String group);

  /// No description provided for @recurringEditNote.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to copies added from now on. Copies already added stay as they are.'**
  String get recurringEditNote;

  /// No description provided for @recurringSaved.
  ///
  /// In en, this message translates to:
  /// **'Future copies updated'**
  String get recurringSaved;

  /// No description provided for @recurringNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Not on this phone'**
  String get recurringNotFoundTitle;

  /// No description provided for @recurringNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This repeating expense isn\'t on this phone any more.'**
  String get recurringNotFoundBody;

  /// No description provided for @recurringDeleteAlsoStops.
  ///
  /// In en, this message translates to:
  /// **'Deleted. It won\'t repeat any more.'**
  String get recurringDeleteAlsoStops;

  /// No description provided for @actRecurringCopy.
  ///
  /// In en, this message translates to:
  /// **'“{description}” was added (repeats)'**
  String actRecurringCopy(String description);

  /// No description provided for @actRecurringStoppedAuto.
  ///
  /// In en, this message translates to:
  /// **'“{description}” stopped repeating'**
  String actRecurringStoppedAuto(String description);

  /// No description provided for @searchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search expenses'**
  String get searchTooltip;

  /// No description provided for @searchFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Search expenses'**
  String get searchFieldHint;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// No description provided for @searchFilterGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get searchFilterGroup;

  /// No description provided for @searchFilterPerson.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get searchFilterPerson;

  /// No description provided for @searchFilterDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get searchFilterDate;

  /// No description provided for @searchFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get searchFilterCategory;

  /// No description provided for @searchAnyGroup.
  ///
  /// In en, this message translates to:
  /// **'All groups'**
  String get searchAnyGroup;

  /// No description provided for @searchAnyPerson.
  ///
  /// In en, this message translates to:
  /// **'Anyone'**
  String get searchAnyPerson;

  /// No description provided for @searchAnyDate.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get searchAnyDate;

  /// No description provided for @searchAnyCategory.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get searchAnyCategory;

  /// No description provided for @searchThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get searchThisMonth;

  /// No description provided for @searchLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get searchLastMonth;

  /// No description provided for @searchLast3Months.
  ///
  /// In en, this message translates to:
  /// **'Last 3 months'**
  String get searchLast3Months;

  /// No description provided for @searchThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get searchThisYear;

  /// No description provided for @searchPickDates.
  ///
  /// In en, this message translates to:
  /// **'Pick dates'**
  String get searchPickDates;

  /// No description provided for @searchFromTitle.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get searchFromTitle;

  /// No description provided for @searchToTitle.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get searchToTitle;

  /// No description provided for @searchDateRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String searchDateRange(String from, String to);

  /// No description provided for @searchStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Find any expense'**
  String get searchStartTitle;

  /// No description provided for @searchStartBody.
  ///
  /// In en, this message translates to:
  /// **'Search by description, note, person or amount. It works offline too.'**
  String get searchStartBody;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try another word, or remove a filter.'**
  String get searchNoResultsBody;

  /// No description provided for @searchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense} other{{count} expenses}}'**
  String searchResultCount(int count);

  /// No description provided for @searchLimited.
  ///
  /// In en, this message translates to:
  /// **'Showing the newest {count}'**
  String searchLimited(int count);

  /// No description provided for @searchClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get searchClearFilters;

  /// No description provided for @searchNoPeople.
  ///
  /// In en, this message translates to:
  /// **'No people yet'**
  String get searchNoPeople;

  /// No description provided for @impTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from Splitwise'**
  String get impTitle;

  /// No description provided for @impStepFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get impStepFile;

  /// No description provided for @impStepGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get impStepGroup;

  /// No description provided for @impStepPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get impStepPeople;

  /// No description provided for @impStepPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get impStepPreview;

  /// No description provided for @impStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get impStepDone;

  /// No description provided for @impFileQuestion.
  ///
  /// In en, this message translates to:
  /// **'Bring a Splitwise group over'**
  String get impFileQuestion;

  /// No description provided for @impHow1.
  ///
  /// In en, this message translates to:
  /// **'In Splitwise, open the group, tap the settings gear, then Export as spreadsheet.'**
  String get impHow1;

  /// No description provided for @impHow2.
  ///
  /// In en, this message translates to:
  /// **'Save the CSV file on this phone, then choose it here.'**
  String get impHow2;

  /// No description provided for @impHow3.
  ///
  /// In en, this message translates to:
  /// **'Files exported from Splitify work too.'**
  String get impHow3;

  /// No description provided for @impChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose CSV file'**
  String get impChooseFile;

  /// No description provided for @impIntoGroup.
  ///
  /// In en, this message translates to:
  /// **'Import into'**
  String get impIntoGroup;

  /// No description provided for @impFileRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}} · {currencies}'**
  String impFileRows(int count, String currencies);

  /// No description provided for @impChangeFile.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get impChangeFile;

  /// No description provided for @impPreviewButton.
  ///
  /// In en, this message translates to:
  /// **'Preview import'**
  String get impPreviewButton;

  /// No description provided for @impChooseAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get impChooseAnother;

  /// No description provided for @impErrTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t read this file'**
  String get impErrTitle;

  /// No description provided for @impErrEmpty.
  ///
  /// In en, this message translates to:
  /// **'This file is empty.'**
  String get impErrEmpty;

  /// No description provided for @impErrHeader.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look like a Splitwise or Splitify export. Its first row should start with Date, Description, Category.'**
  String get impErrHeader;

  /// No description provided for @impErrColumns.
  ///
  /// In en, this message translates to:
  /// **'Row {row} has a different number of cells than the first row.'**
  String impErrColumns(int row);

  /// No description provided for @impErrDate.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: “{value}” is not a date (YYYY-MM-DD).'**
  String impErrDate(int row, String value);

  /// No description provided for @impErrCurrency.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: “{value}” is not a currency code.'**
  String impErrCurrency(int row, String value);

  /// No description provided for @impErrAmount.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: “{value}” is not an amount.'**
  String impErrAmount(int row, String value);

  /// No description provided for @impErrUnbalanced.
  ///
  /// In en, this message translates to:
  /// **'Row {row} doesn\'t add up: someone\'s share is missing.'**
  String impErrUnbalanced(int row);

  /// No description provided for @impErrDuplicateTotals.
  ///
  /// In en, this message translates to:
  /// **'Row {row} repeats the Total balance row for {value}.'**
  String impErrDuplicateTotals(int row, String value);

  /// No description provided for @impErrTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is larger than 5 MB.'**
  String get impErrTooLarge;

  /// No description provided for @impErrNoRows.
  ///
  /// In en, this message translates to:
  /// **'There are no expenses or payments in this file.'**
  String get impErrNoRows;

  /// No description provided for @impErrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Splitify can\'t handle {code} amounts yet.'**
  String impErrUnsupported(String code);

  /// No description provided for @impEarlier.
  ///
  /// In en, this message translates to:
  /// **'Imported on this phone'**
  String get impEarlier;

  /// No description provided for @impBatchTitle.
  ///
  /// In en, this message translates to:
  /// **'{file}'**
  String impBatchTitle(String file);

  /// No description provided for @impBatchWhen.
  ///
  /// In en, this message translates to:
  /// **'Imported {date}'**
  String impBatchWhen(String date);

  /// No description provided for @impGroupQuestion.
  ///
  /// In en, this message translates to:
  /// **'Where should it go?'**
  String get impGroupQuestion;

  /// No description provided for @impNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get impNewGroup;

  /// No description provided for @impGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get impGroupName;

  /// No description provided for @impGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Goa trip'**
  String get impGroupNameHint;

  /// No description provided for @impYourGroups.
  ///
  /// In en, this message translates to:
  /// **'Your groups'**
  String get impYourGroups;

  /// No description provided for @impContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get impContinue;

  /// No description provided for @impPeopleQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who is who?'**
  String get impPeopleQuestion;

  /// No description provided for @impPeopleHint.
  ///
  /// In en, this message translates to:
  /// **'Match each person in the file to someone in “{group}”.'**
  String impPeopleHint(String group);

  /// No description provided for @impPeopleHintNew.
  ///
  /// In en, this message translates to:
  /// **'Match each person in the file. Everyone except you joins as a name-only member.'**
  String get impPeopleHintNew;

  /// No description provided for @impChoiceNew.
  ///
  /// In en, this message translates to:
  /// **'New person'**
  String get impChoiceNew;

  /// No description provided for @impChoiceSkip.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get impChoiceSkip;

  /// No description provided for @impPickFor.
  ///
  /// In en, this message translates to:
  /// **'Who is {name}?'**
  String impPickFor(String name);

  /// No description provided for @impAddNew.
  ///
  /// In en, this message translates to:
  /// **'Add “{name}” as a new person'**
  String impAddNew(String name);

  /// No description provided for @impSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip {name}'**
  String impSkip(String name);

  /// No description provided for @impSkipBody.
  ///
  /// In en, this message translates to:
  /// **'Rows that involve them are left out.'**
  String get impSkipBody;

  /// No description provided for @impNetPlus.
  ///
  /// In en, this message translates to:
  /// **'gets back {amount}'**
  String impNetPlus(String amount);

  /// No description provided for @impNetMinus.
  ///
  /// In en, this message translates to:
  /// **'owes {amount}'**
  String impNetMinus(String amount);

  /// No description provided for @impNetZero.
  ///
  /// In en, this message translates to:
  /// **'settled up'**
  String get impNetZero;

  /// No description provided for @impProblemSameMember.
  ///
  /// In en, this message translates to:
  /// **'Two people in the file are matched to the same member.'**
  String get impProblemSameMember;

  /// No description provided for @impProblemEmptyName.
  ///
  /// In en, this message translates to:
  /// **'A new person needs a name.'**
  String get impProblemEmptyName;

  /// No description provided for @impProblemNobody.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one person to import.'**
  String get impProblemNobody;

  /// No description provided for @impProblemTooMany.
  ///
  /// In en, this message translates to:
  /// **'A group can have up to 100 members.'**
  String get impProblemTooMany;

  /// No description provided for @impPreviewQuestion.
  ///
  /// In en, this message translates to:
  /// **'Check before importing'**
  String get impPreviewQuestion;

  /// No description provided for @impCountExpenses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense} other{{count} expenses}}'**
  String impCountExpenses(int count);

  /// No description provided for @impCountPayments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 payment} other{{count} payments}}'**
  String impCountPayments(int count);

  /// No description provided for @impDateRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String impDateRange(String from, String to);

  /// No description provided for @impStatExpenses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Expense} other{Expenses}}'**
  String impStatExpenses(int count);

  /// No description provided for @impStatPayments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Payment} other{Payments}}'**
  String impStatPayments(int count);

  /// No description provided for @impStatPeople.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Person} other{People}}'**
  String impStatPeople(int count);

  /// No description provided for @impTotalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Total balance check'**
  String get impTotalsTitle;

  /// No description provided for @impTotalsOk.
  ///
  /// In en, this message translates to:
  /// **'Matches the file'**
  String get impTotalsOk;

  /// No description provided for @impTotalsNone.
  ///
  /// In en, this message translates to:
  /// **'No Total balance row to check against'**
  String get impTotalsNone;

  /// No description provided for @impTotalsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t match the file'**
  String get impTotalsMismatch;

  /// No description provided for @impMismatchRow.
  ///
  /// In en, this message translates to:
  /// **'{name}: the file says {file}, its rows add up to {rows}'**
  String impMismatchRow(String name, String file, String rows);

  /// No description provided for @impImportAnyway.
  ///
  /// In en, this message translates to:
  /// **'Import anyway'**
  String get impImportAnyway;

  /// No description provided for @impImportAnywaySub.
  ///
  /// In en, this message translates to:
  /// **'Balances follow the rows, not the Total balance row.'**
  String get impImportAnywaySub;

  /// No description provided for @impDropped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row involves someone you skipped and is left out.} other{{count} rows involve people you skipped and are left out.}}'**
  String impDropped(int count);

  /// No description provided for @impZeroRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row changes nobody\'s balance and is left out.} other{{count} rows change nobody\'s balance and are left out.}}'**
  String impZeroRows(int count);

  /// No description provided for @impNetsRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense with several payers comes in as net amounts; its original cost goes in the notes.} other{{count} expenses with several payers come in as net amounts; their original cost goes in the notes.}}'**
  String impNetsRows(int count);

  /// No description provided for @impBalancesAfter.
  ///
  /// In en, this message translates to:
  /// **'Balances from this file'**
  String get impBalancesAfter;

  /// No description provided for @impImportButton.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Import 1 record} other{Import {count} records}}'**
  String impImportButton(int count);

  /// No description provided for @impRunning.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get impRunning;

  /// No description provided for @impRunningCount.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String impRunningCount(int done, int total);

  /// No description provided for @impDoneLead.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get impDoneLead;

  /// No description provided for @impDoneHighlight.
  ///
  /// In en, this message translates to:
  /// **'imported'**
  String get impDoneHighlight;

  /// No description provided for @impDoneBody.
  ///
  /// In en, this message translates to:
  /// **'{expenses} and {payments} are in “{group}”.'**
  String impDoneBody(String expenses, String payments, String group);

  /// No description provided for @impOpenGroup.
  ///
  /// In en, this message translates to:
  /// **'Open group'**
  String get impOpenGroup;

  /// No description provided for @impDeleteImport.
  ///
  /// In en, this message translates to:
  /// **'Delete this import'**
  String get impDeleteImport;

  /// No description provided for @impDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this import?'**
  String get impDeleteTitle;

  /// No description provided for @impDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Every expense and payment from this file is deleted. You can bring them back one by one from Deleted items.'**
  String get impDeleteBody;

  /// No description provided for @impDeleted.
  ///
  /// In en, this message translates to:
  /// **'Import deleted'**
  String get impDeleted;

  /// No description provided for @impDeletedBody.
  ///
  /// In en, this message translates to:
  /// **'The records from this file are deleted. People added for the import stay in the group.'**
  String get impDeletedBody;

  /// No description provided for @impFallbackDescription.
  ///
  /// In en, this message translates to:
  /// **'Imported expense'**
  String get impFallbackDescription;

  /// No description provided for @actImportCompletedFile.
  ///
  /// In en, this message translates to:
  /// **'{actor} imported expenses from a Splitify file'**
  String actImportCompletedFile(String actor);

  /// No description provided for @actImportUndone.
  ///
  /// In en, this message translates to:
  /// **'{actor} deleted an import'**
  String actImportUndone(String actor);

  /// No description provided for @actImportCounts.
  ///
  /// In en, this message translates to:
  /// **'{expenses} · {payments}'**
  String actImportCounts(String expenses, String payments);

  /// No description provided for @lockSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get lockSecurity;

  /// No description provided for @lockSecuritySubtitle.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get lockSecuritySubtitle;

  /// No description provided for @lockAppLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get lockAppLock;

  /// No description provided for @lockAppLockSub.
  ///
  /// In en, this message translates to:
  /// **'Ask for your fingerprint or screen lock to open Splitify.'**
  String get lockAppLockSub;

  /// No description provided for @lockAfter.
  ///
  /// In en, this message translates to:
  /// **'Lock after'**
  String get lockAfter;

  /// No description provided for @lockMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String lockMinutes(int count);

  /// No description provided for @lockMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String lockMinutesShort(int count);

  /// No description provided for @lockAfterSub.
  ///
  /// In en, this message translates to:
  /// **'Splitify locks after this long in the background, and always when it starts.'**
  String get lockAfterSub;

  /// No description provided for @lockRecentsNote.
  ///
  /// In en, this message translates to:
  /// **'While app lock is on, the preview of Splitify in recent apps is hidden.'**
  String get lockRecentsNote;

  /// No description provided for @lockNeedsScreenLock.
  ///
  /// In en, this message translates to:
  /// **'Set a screen lock (PIN, pattern, password or fingerprint) on this phone first.'**
  String get lockNeedsScreenLock;

  /// No description provided for @lockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Splitify'**
  String get lockReason;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Splitify is locked'**
  String get lockTitle;

  /// No description provided for @lockBody.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint or screen lock to see your groups and balances.'**
  String get lockBody;

  /// No description provided for @lockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockUnlock;

  /// No description provided for @lockOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get lockOn;

  /// No description provided for @lockOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get lockOff;

  /// No description provided for @lockConfirmFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm it\'s you. Try again.'**
  String get lockConfirmFailed;

  /// No description provided for @lockTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'This phone has no screen lock any more, so app lock is off.'**
  String get lockTurnedOff;

  /// No description provided for @widgetRow.
  ///
  /// In en, this message translates to:
  /// **'Home screen widget'**
  String get widgetRow;

  /// No description provided for @widgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Home screen widget'**
  String get widgetTitle;

  /// No description provided for @widgetHowTo.
  ///
  /// In en, this message translates to:
  /// **'Long-press your home screen, tap Widgets and pick Splitify. It shows your overall balance and opens the app when tapped.'**
  String get widgetHowTo;

  /// No description provided for @widgetHideAmounts.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts'**
  String get widgetHideAmounts;

  /// No description provided for @widgetHideAmountsSub.
  ///
  /// In en, this message translates to:
  /// **'The widget shows whether you owe or are owed, without numbers.'**
  String get widgetHideAmountsSub;

  /// No description provided for @widgetUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String widgetUpdated(String time);

  /// No description provided for @widgetUpdatedNow.
  ///
  /// In en, this message translates to:
  /// **'Updated just now'**
  String get widgetUpdatedNow;

  /// No description provided for @widgetNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get widgetNotSynced;

  /// No description provided for @widgetSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Open Splitify to sign in'**
  String get widgetSignedOut;

  /// No description provided for @widgetHidden.
  ///
  /// In en, this message translates to:
  /// **'Amounts hidden'**
  String get widgetHidden;

  /// No description provided for @widgetBrand.
  ///
  /// In en, this message translates to:
  /// **'Splitify'**
  String get widgetBrand;

  /// Shown when a splitify:// link or a route does not exist (final QA, S-250).
  ///
  /// In en, this message translates to:
  /// **'This link doesn\'t open anything'**
  String get linkNotFoundTitle;

  /// No description provided for @linkNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may be old or mistyped. Your groups are one tap away.'**
  String get linkNotFoundBody;

  /// No description provided for @linkNotFoundAction.
  ///
  /// In en, this message translates to:
  /// **'Go to groups'**
  String get linkNotFoundAction;

  /// Caption under your own net in Balances (“You … get back”).
  ///
  /// In en, this message translates to:
  /// **'get back'**
  String get balYouGetBack;

  /// Caption under your own net in Balances (“You … owe”).
  ///
  /// In en, this message translates to:
  /// **'owe'**
  String get balYouOwe;

  /// Sync & storage headline when photo uploads gave up (final QA).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo stopped uploading} other{{count} photos stopped uploading}}'**
  String syncStatePhotosStopped(int count);

  /// No description provided for @syncStatePhotosStoppedHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Retry under Photos below.'**
  String get syncStatePhotosStoppedHint;

  /// No description provided for @syncStatePhotosWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo waiting to upload} other{{count} photos waiting to upload}}'**
  String syncStatePhotosWaiting(int count);

  /// No description provided for @syncRowPhotosStopped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo stopped} other{{count} photos stopped}}'**
  String syncRowPhotosStopped(int count);

  /// Button on the blocked-push banner: opens Android's notification settings for Splitify (final QA).
  ///
  /// In en, this message translates to:
  /// **'Open phone settings'**
  String get notifOpenSettings;
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
