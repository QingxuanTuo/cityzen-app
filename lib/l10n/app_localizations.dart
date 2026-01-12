import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'CityZen'**
  String get appTitle;

  /// Home navigation label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Map navigation label
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// AI Chat navigation label
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get aiChat;

  /// Settings navigation label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Profile section title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Location label
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Location & Data section title
  ///
  /// In en, this message translates to:
  /// **'Location & Data'**
  String get locationAndData;

  /// Notifications section title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Language label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Italian language name
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get italian;

  /// Italian language name in Italian
  ///
  /// In en, this message translates to:
  /// **'Italiano'**
  String get italiano;

  /// Location Services label
  ///
  /// In en, this message translates to:
  /// **'Location Services'**
  String get locationServices;

  /// Enabled status
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// Disabled status
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// Push Notifications label
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// Default user name
  ///
  /// In en, this message translates to:
  /// **'CityZen User'**
  String get cityZenUser;

  /// Default user description
  ///
  /// In en, this message translates to:
  /// **'Environmental Health Enthusiast'**
  String get environmentalHealthEnthusiast;

  /// Edit Profile dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Description field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Profile update success message
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdatedSuccessfully;

  /// Quick Questions section title
  ///
  /// In en, this message translates to:
  /// **'Quick Questions'**
  String get quickQuestions;

  /// Air Quality quick question title
  ///
  /// In en, this message translates to:
  /// **'Air Quality'**
  String get airQuality;

  /// Air Quality quick question
  ///
  /// In en, this message translates to:
  /// **'What is the current air quality like?'**
  String get whatIsCurrentAirQuality;

  /// Outdoor Activity quick question title
  ///
  /// In en, this message translates to:
  /// **'Outdoor Activity'**
  String get outdoorActivity;

  /// Outdoor Activity quick question
  ///
  /// In en, this message translates to:
  /// **'Is it safe to exercise outdoors today?'**
  String get isItSafeToExerciseOutdoors;

  /// Health Tips quick question title
  ///
  /// In en, this message translates to:
  /// **'Health Tips'**
  String get healthTips;

  /// Health Tips quick question
  ///
  /// In en, this message translates to:
  /// **'Give me health recommendations for today'**
  String get giveMeHealthRecommendations;

  /// Precautions quick question title
  ///
  /// In en, this message translates to:
  /// **'Precautions'**
  String get precautions;

  /// Precautions quick question
  ///
  /// In en, this message translates to:
  /// **'What precautions should I take today?'**
  String get whatPrecautionsShouldITake;

  /// AI Chat input placeholder
  ///
  /// In en, this message translates to:
  /// **'Ask about environmental health...'**
  String get askAboutEnvironmentalHealth;

  /// AI loading message
  ///
  /// In en, this message translates to:
  /// **'AI is thinking...'**
  String get aiIsThinking;

  /// AI not configured title
  ///
  /// In en, this message translates to:
  /// **'AI Assistant Not Configured'**
  String get aiAssistantNotConfigured;

  /// AI not configured message
  ///
  /// In en, this message translates to:
  /// **'To use the AI environmental health assistant, you need to configure your Gemini API key.'**
  String get aiNotConfiguredMessage;

  /// Default location
  ///
  /// In en, this message translates to:
  /// **'Milan, Italy'**
  String get milanItaly;

  /// Map page title
  ///
  /// In en, this message translates to:
  /// **'Environmental Health Map'**
  String get environmentalHealthMap;

  /// Morning greeting
  ///
  /// In en, this message translates to:
  /// **'Good Morning!'**
  String get goodMorning;

  /// Afternoon greeting
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon!'**
  String get goodAfternoon;

  /// Evening greeting
  ///
  /// In en, this message translates to:
  /// **'Good Evening!'**
  String get goodEvening;

  /// PM2.5 label
  ///
  /// In en, this message translates to:
  /// **'PM2.5'**
  String get pm25;

  /// Wind label
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get wind;

  /// Humidity label
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidity;

  /// Temperature label
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// No data message
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataAvailable;

  /// Loading error message
  ///
  /// In en, this message translates to:
  /// **'Loading failed'**
  String get loadingFailed;

  /// AI Chat welcome message
  ///
  /// In en, this message translates to:
  /// **'Hello! I\'m your AI Environmental Health Assistant. I can provide daily life recommendations based on real-time environmental data to help you reduce environmental exposure risks. What would you like to know?'**
  String get aiWelcomeMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
