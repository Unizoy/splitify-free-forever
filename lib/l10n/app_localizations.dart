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
