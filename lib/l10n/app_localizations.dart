import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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
    Locale('zh'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'TouchFish'**
  String get appName;

  /// Application subtitle on welcome screen
  ///
  /// In en, this message translates to:
  /// **'Modern instant messaging'**
  String get appSubtitle;

  /// Button to start using the app
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get welcomeStart;

  /// No description provided for @welcomeFeatureLightweightTitle.
  ///
  /// In en, this message translates to:
  /// **'Lightweight'**
  String get welcomeFeatureLightweightTitle;

  /// No description provided for @welcomeFeatureLightweightDesc.
  ///
  /// In en, this message translates to:
  /// **'Efficient and resource-friendly design'**
  String get welcomeFeatureLightweightDesc;

  /// No description provided for @welcomeFeatureMultiplatformTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-platform'**
  String get welcomeFeatureMultiplatformTitle;

  /// No description provided for @welcomeFeatureMultiplatformDesc.
  ///
  /// In en, this message translates to:
  /// **'Support Windows, macOS, Linux, Android and Web'**
  String get welcomeFeatureMultiplatformDesc;

  /// No description provided for @welcomeFeatureLanTitle.
  ///
  /// In en, this message translates to:
  /// **'No Internet'**
  String get welcomeFeatureLanTitle;

  /// No description provided for @welcomeFeatureLanDesc.
  ///
  /// In en, this message translates to:
  /// **'No Internet connection needed, works seamlessly on LAN'**
  String get welcomeFeatureLanDesc;

  /// No description provided for @loginUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get loginUsername;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginLogin;

  /// No description provided for @loginRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get loginRegister;

  /// No description provided for @loginMsgLoginNotImpl.
  ///
  /// In en, this message translates to:
  /// **'Login function not implemented yet'**
  String get loginMsgLoginNotImpl;

  /// No description provided for @loginMsgRegisterNotImpl.
  ///
  /// In en, this message translates to:
  /// **'Register function not implemented yet'**
  String get loginMsgRegisterNotImpl;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// No description provided for @registerCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create New Account'**
  String get registerCreateAccount;

  /// No description provided for @registerAccountInfo.
  ///
  /// In en, this message translates to:
  /// **'Set up your account'**
  String get registerAccountInfo;

  /// No description provided for @registerEmailInfo.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get registerEmailInfo;

  /// No description provided for @registerVerifyInfo.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get registerVerifyInfo;

  /// No description provided for @registerUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get registerUsername;

  /// No description provided for @registerPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get registerPassword;

  /// No description provided for @registerConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get registerConfirmPassword;

  /// No description provided for @registerEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get registerEmail;

  /// No description provided for @registerVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code (6 digits)'**
  String get registerVerificationCode;

  /// No description provided for @registerNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get registerNextStep;

  /// No description provided for @registerPreviousStep.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get registerPreviousStep;

  /// No description provided for @registerComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get registerComplete;

  /// No description provided for @registerHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Back to login'**
  String get registerHaveAccount;

  /// No description provided for @registerSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration Successful!'**
  String get registerSuccess;

  /// No description provided for @registerSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been created successfully'**
  String get registerSuccessMessage;

  /// No description provided for @registerBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get registerBackToLogin;

  /// No description provided for @registerErrorUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter username'**
  String get registerErrorUsernameRequired;

  /// No description provided for @registerErrorUsernameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters'**
  String get registerErrorUsernameMinLength;

  /// No description provided for @registerErrorPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get registerErrorPasswordRequired;

  /// No description provided for @registerErrorConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter password again'**
  String get registerErrorConfirmPasswordRequired;

  /// No description provided for @registerErrorPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get registerErrorPasswordMismatch;

  /// No description provided for @registerErrorVerificationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter verification code'**
  String get registerErrorVerificationCodeRequired;

  /// No description provided for @registerErrorVerificationCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Verification code must be 6 digits'**
  String get registerErrorVerificationCodeInvalid;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @settingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No settings'**
  String get settingsEmpty;

  /// No description provided for @settingsCategoryAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsCategoryAppearance;

  /// No description provided for @settingsCategoryNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsCategoryNotifications;

  /// No description provided for @settingsCategoryAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsCategoryAbout;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Language of the application'**
  String get settingsLanguageDesc;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageZh.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageZh;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeTitle;

  /// No description provided for @settingsThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Appearance theme of the application'**
  String get settingsThemeDesc;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Color'**
  String get settingsThemeColorTitle;

  /// No description provided for @settingsThemeColorDesc.
  ///
  /// In en, this message translates to:
  /// **'Primary color used in the application'**
  String get settingsThemeColorDesc;

  /// No description provided for @settingsColorDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsColorDefault;

  /// No description provided for @settingsColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get settingsColorRed;

  /// No description provided for @settingsColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get settingsColorGreen;

  /// No description provided for @settingsColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get settingsColorPurple;

  /// No description provided for @settingsColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get settingsColorOrange;

  /// No description provided for @settingsSendModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Mode'**
  String get settingsSendModeTitle;

  /// No description provided for @settingsSendModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcut for sending messages'**
  String get settingsSendModeDesc;

  /// No description provided for @settingsSendModeEnter.
  ///
  /// In en, this message translates to:
  /// **'Press Enter to send'**
  String get settingsSendModeEnter;

  /// No description provided for @settingsSendModeCtrlEnter.
  ///
  /// In en, this message translates to:
  /// **'Press Ctrl+Enter to send'**
  String get settingsSendModeCtrlEnter;

  /// No description provided for @settingsSystemNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'System Notifications'**
  String get settingsSystemNotificationsTitle;

  /// No description provided for @settingsSystemNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Use system notifications for messages'**
  String get settingsSystemNotificationsDesc;

  /// No description provided for @settingsInAppNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'In-App Notifications'**
  String get settingsInAppNotificationsTitle;

  /// No description provided for @settingsInAppNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Show notifications within the application'**
  String get settingsInAppNotificationsDesc;

  /// No description provided for @settingsNotificationSoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Sound'**
  String get settingsNotificationSoundTitle;

  /// No description provided for @settingsNotificationSoundDesc.
  ///
  /// In en, this message translates to:
  /// **'Play sound for in-app notifications'**
  String get settingsNotificationSoundDesc;

  /// No description provided for @settingsChatNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Notifications'**
  String get settingsChatNotificationsTitle;

  /// No description provided for @settingsChatNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure notification settings for private and group chats'**
  String get settingsChatNotificationsDesc;

  /// No description provided for @settingsPrivateChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Private Chat Notifications'**
  String get settingsPrivateChatTitle;

  /// No description provided for @settingsGroupChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Group Chat Notifications'**
  String get settingsGroupChatTitle;

  /// No description provided for @settingsAboutAppTitle.
  ///
  /// In en, this message translates to:
  /// **'About Application'**
  String get settingsAboutAppTitle;

  /// No description provided for @serverTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverTitle;

  /// No description provided for @serverAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get serverAdd;

  /// No description provided for @serverEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Server'**
  String get serverEdit;

  /// No description provided for @serverDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Server'**
  String get serverDelete;

  /// No description provided for @serverSelect.
  ///
  /// In en, this message translates to:
  /// **'Select Server'**
  String get serverSelect;

  /// No description provided for @serverUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrlLabel;

  /// No description provided for @serverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., touchfish.xin'**
  String get serverUrlHint;

  /// No description provided for @serverCannotDeleteLast.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete the last server'**
  String get serverCannotDeleteLast;

  /// No description provided for @serverInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid server URL'**
  String get serverInvalidUrl;

  /// No description provided for @serverAddServer.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get serverAddServer;

  /// No description provided for @serverCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get serverCancel;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Announce'**
  String get navAnnouncement;

  /// No description provided for @navForum.
  ///
  /// In en, this message translates to:
  /// **'Forum'**
  String get navForum;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @chatTabMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatTabMessages;

  /// No description provided for @chatTabContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get chatTabContacts;

  /// No description provided for @chatInvites.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get chatInvites;

  /// No description provided for @chatNoInvites.
  ///
  /// In en, this message translates to:
  /// **'No invites'**
  String get chatNoInvites;

  /// No description provided for @chatPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get chatPinned;

  /// No description provided for @chatDirectMessage.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get chatDirectMessage;

  /// No description provided for @chatGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get chatGroupMessage;

  /// No description provided for @chatOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get chatOnline;

  /// No description provided for @chatOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chatOffline;

  /// No description provided for @chatAway.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get chatAway;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
