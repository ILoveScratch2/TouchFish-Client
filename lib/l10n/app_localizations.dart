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

  /// No description provided for @settingsEnableMarkdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Render Markdown/LaTeX'**
  String get settingsEnableMarkdownTitle;

  /// No description provided for @settingsEnableMarkdownDesc.
  ///
  /// In en, this message translates to:
  /// **'Render Markdown and LaTeX formatted text'**
  String get settingsEnableMarkdownDesc;

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

  /// No description provided for @serverDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get serverDisplayName;

  /// No description provided for @serverDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., TOUCHFISH Server'**
  String get serverDisplayNameHint;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server Address'**
  String get serverAddress;

  /// No description provided for @serverAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., touchfish.xin'**
  String get serverAddressHint;

  /// No description provided for @serverApiPort.
  ///
  /// In en, this message translates to:
  /// **'API Port'**
  String get serverApiPort;

  /// No description provided for @serverApiPortHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 8080'**
  String get serverApiPortHint;

  /// No description provided for @serverTcpPort.
  ///
  /// In en, this message translates to:
  /// **'TCP Port'**
  String get serverTcpPort;

  /// No description provided for @serverTcpPortHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 9090'**
  String get serverTcpPortHint;

  /// No description provided for @serverErrorInvalidAddress.
  ///
  /// In en, this message translates to:
  /// **'Invalid address'**
  String get serverErrorInvalidAddress;

  /// No description provided for @serverErrorInvalidPort.
  ///
  /// In en, this message translates to:
  /// **'Port must be an integer between 0 and 65535'**
  String get serverErrorInvalidPort;

  /// No description provided for @serverErrorDuplicatePort.
  ///
  /// In en, this message translates to:
  /// **'Ports cannot be the same'**
  String get serverErrorDuplicatePort;

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

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @accountUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Not Logged In'**
  String get accountUnauthorized;

  /// No description provided for @accountLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get accountLogin;

  /// No description provided for @accountCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get accountCreateAccount;

  /// No description provided for @accountCreateAccountDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign up for a new account'**
  String get accountCreateAccountDescription;

  /// No description provided for @accountLoginDescription.
  ///
  /// In en, this message translates to:
  /// **'Log in to your account'**
  String get accountLoginDescription;

  /// No description provided for @accountNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get accountNotifications;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get accountSettings;

  /// No description provided for @accountEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get accountEditProfile;

  /// No description provided for @accountProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get accountProfile;

  /// No description provided for @accountAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get accountAbout;

  /// No description provided for @accountDebugOptions.
  ///
  /// In en, this message translates to:
  /// **'Debug Options'**
  String get accountDebugOptions;

  /// No description provided for @accountLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get accountLogout;

  /// No description provided for @accountLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get accountLogoutConfirm;

  /// No description provided for @accountDescriptionNone.
  ///
  /// In en, this message translates to:
  /// **'No signature'**
  String get accountDescriptionNone;

  /// No description provided for @accountSignature.
  ///
  /// In en, this message translates to:
  /// **'Personal Signature'**
  String get accountSignature;

  /// No description provided for @accountEditSignature.
  ///
  /// In en, this message translates to:
  /// **'Edit Signature'**
  String get accountEditSignature;

  /// No description provided for @accountCreateSignature.
  ///
  /// In en, this message translates to:
  /// **'Create Signature'**
  String get accountCreateSignature;

  /// No description provided for @accountUpdateSignature.
  ///
  /// In en, this message translates to:
  /// **'Update Signature'**
  String get accountUpdateSignature;

  /// No description provided for @accountSignaturePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your personal signature...'**
  String get accountSignaturePlaceholder;

  /// No description provided for @accountAppSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get accountAppSettings;

  /// No description provided for @accountUpdateYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Update Your Profile'**
  String get accountUpdateYourProfile;

  /// No description provided for @profileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditTitle;

  /// No description provided for @profileEditAvatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get profileEditAvatar;

  /// No description provided for @profileEditBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get profileEditBackground;

  /// No description provided for @profileEditBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get profileEditBasicInfo;

  /// No description provided for @profileEditUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileEditUsername;

  /// No description provided for @profileEditEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEditEmail;

  /// No description provided for @profileEditBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileEditBio;

  /// No description provided for @profileEditBioPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself...'**
  String get profileEditBioPlaceholder;

  /// No description provided for @profileEditIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get profileEditIntroduction;

  /// No description provided for @profileEditIntroductionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write something about yourself...'**
  String get profileEditIntroductionPlaceholder;

  /// No description provided for @profileEditSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get profileEditSaveChanges;

  /// No description provided for @profileEditChangeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change Avatar'**
  String get profileEditChangeAvatar;

  /// No description provided for @profileEditChangeBackground.
  ///
  /// In en, this message translates to:
  /// **'Change Background'**
  String get profileEditChangeBackground;

  /// No description provided for @profileEditRemoveAvatar.
  ///
  /// In en, this message translates to:
  /// **'Remove Avatar'**
  String get profileEditRemoveAvatar;

  /// No description provided for @profileEditRemoveBackground.
  ///
  /// In en, this message translates to:
  /// **'Remove Background'**
  String get profileEditRemoveBackground;

  /// No description provided for @profileEditUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileEditUpdated;

  /// No description provided for @profileEditUsernameCannotChange.
  ///
  /// In en, this message translates to:
  /// **'Username cannot be changed'**
  String get profileEditUsernameCannotChange;

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

  /// No description provided for @chatDetailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get chatDetailLoading;

  /// No description provided for @chatDetailUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get chatDetailUnknownUser;

  /// No description provided for @chatDetailOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get chatDetailOther;

  /// No description provided for @chatDetailGroupChat.
  ///
  /// In en, this message translates to:
  /// **'Group Chat'**
  String get chatDetailGroupChat;

  /// No description provided for @chatDetailNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet\nSend a message to start chatting'**
  String get chatDetailNoMessages;

  /// No description provided for @chatInputCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get chatInputCollapse;

  /// No description provided for @chatInputExpand.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatInputExpand;

  /// No description provided for @chatInputAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get chatInputAttachment;

  /// No description provided for @chatInputTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get chatInputTakePhoto;

  /// No description provided for @chatInputTakeVideo.
  ///
  /// In en, this message translates to:
  /// **'Record Video'**
  String get chatInputTakeVideo;

  /// No description provided for @chatInputUploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get chatInputUploadFile;

  /// No description provided for @chatInputRecordAudio.
  ///
  /// In en, this message translates to:
  /// **'Record Audio'**
  String get chatInputRecordAudio;

  /// No description provided for @chatInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatInputPlaceholder;

  /// No description provided for @chatInputFeatureArea.
  ///
  /// In en, this message translates to:
  /// **'Feature Area'**
  String get chatInputFeatureArea;

  /// No description provided for @networkStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Network Status'**
  String get networkStatusTitle;

  /// No description provided for @networkStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to Internet'**
  String get networkStatusConnected;

  /// No description provided for @networkStatusConnectedDesc.
  ///
  /// In en, this message translates to:
  /// **'You are connected to the internet and can connect to TouchFish servers on the public network'**
  String get networkStatusConnectedDesc;

  /// No description provided for @networkStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected from Internet'**
  String get networkStatusDisconnected;

  /// No description provided for @networkStatusDisconnectedDesc.
  ///
  /// In en, this message translates to:
  /// **'You are disconnected from the internet and can only connect to local network servers'**
  String get networkStatusDisconnectedDesc;

  /// No description provided for @networkStatusCheckingConnection.
  ///
  /// In en, this message translates to:
  /// **'Checking network connection...'**
  String get networkStatusCheckingConnection;

  /// No description provided for @messageActions.
  ///
  /// In en, this message translates to:
  /// **'Message Actions'**
  String get messageActions;

  /// No description provided for @messageActionReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get messageActionReply;

  /// No description provided for @messageActionForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get messageActionForward;

  /// No description provided for @messageActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get messageActionDelete;

  /// No description provided for @chatRoomSettings.
  ///
  /// In en, this message translates to:
  /// **'Chat Settings'**
  String get chatRoomSettings;

  /// No description provided for @chatRoomMembers.
  ///
  /// In en, this message translates to:
  /// **'Chat Members'**
  String get chatRoomMembers;

  /// No description provided for @chatRoomEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Chat'**
  String get chatRoomEdit;

  /// No description provided for @chatRoomEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get chatRoomEditName;

  /// No description provided for @chatRoomPin.
  ///
  /// In en, this message translates to:
  /// **'Pin Chat'**
  String get chatRoomPin;

  /// No description provided for @chatRoomPinDescription.
  ///
  /// In en, this message translates to:
  /// **'Pin this chat to the top of the list'**
  String get chatRoomPinDescription;

  /// No description provided for @chatRoomPinned.
  ///
  /// In en, this message translates to:
  /// **'Chat pinned'**
  String get chatRoomPinned;

  /// No description provided for @chatRoomUnpinned.
  ///
  /// In en, this message translates to:
  /// **'Chat unpinned'**
  String get chatRoomUnpinned;

  /// No description provided for @chatRoomName.
  ///
  /// In en, this message translates to:
  /// **'Chat Name'**
  String get chatRoomName;

  /// No description provided for @chatRoomContactName.
  ///
  /// In en, this message translates to:
  /// **'Contact Remark Name'**
  String get chatRoomContactName;

  /// No description provided for @chatRoomNameHelp.
  ///
  /// In en, this message translates to:
  /// **'Only editable if you have permission'**
  String get chatRoomNameHelp;

  /// No description provided for @chatRoomAlias.
  ///
  /// In en, this message translates to:
  /// **'Chat Alias'**
  String get chatRoomAlias;

  /// No description provided for @chatRoomAliasHelp.
  ///
  /// In en, this message translates to:
  /// **'Custom name visible only to you'**
  String get chatRoomAliasHelp;

  /// No description provided for @chatRoomDescription.
  ///
  /// In en, this message translates to:
  /// **'Chat Description'**
  String get chatRoomDescription;

  /// No description provided for @chatRoomDescriptionHelp.
  ///
  /// In en, this message translates to:
  /// **'Custom description visible only to you'**
  String get chatRoomDescriptionHelp;

  /// No description provided for @chatRoomNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description yet'**
  String get chatRoomNoDescription;

  /// No description provided for @chatRoomNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Chat name updated'**
  String get chatRoomNameUpdated;

  /// No description provided for @chatRoomUpdated.
  ///
  /// In en, this message translates to:
  /// **'Chat information updated'**
  String get chatRoomUpdated;

  /// No description provided for @chatNotifyLevel.
  ///
  /// In en, this message translates to:
  /// **'Notification Level'**
  String get chatNotifyLevel;

  /// No description provided for @chatNotifyLevelAll.
  ///
  /// In en, this message translates to:
  /// **'All Messages'**
  String get chatNotifyLevelAll;

  /// No description provided for @chatNotifyLevelAllDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications for all messages'**
  String get chatNotifyLevelAllDescription;

  /// No description provided for @chatNotifyLevelMention.
  ///
  /// In en, this message translates to:
  /// **'Mentions Only'**
  String get chatNotifyLevelMention;

  /// No description provided for @chatNotifyLevelMentionDescription.
  ///
  /// In en, this message translates to:
  /// **'Only receive notifications when mentioned'**
  String get chatNotifyLevelMentionDescription;

  /// No description provided for @chatNotifyLevelNone.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get chatNotifyLevelNone;

  /// No description provided for @chatNotifyLevelNoneDescription.
  ///
  /// In en, this message translates to:
  /// **'Do not receive any notifications'**
  String get chatNotifyLevelNoneDescription;

  /// No description provided for @chatSearchMessages.
  ///
  /// In en, this message translates to:
  /// **'Search Messages'**
  String get chatSearchMessages;

  /// No description provided for @chatSearchMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Search for messages in this chat'**
  String get chatSearchMessagesDescription;

  /// No description provided for @chatSearchMessagesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search message content...'**
  String get chatSearchMessagesPlaceholder;

  /// No description provided for @chatSearchMessagesHint.
  ///
  /// In en, this message translates to:
  /// **'Enter keywords to search messages'**
  String get chatSearchMessagesHint;

  /// No description provided for @chatSearchMessagesNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching messages found'**
  String get chatSearchMessagesNoResults;

  /// No description provided for @chatLeaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Leave Chat'**
  String get chatLeaveRoom;

  /// No description provided for @chatLeaveRoomDescription.
  ///
  /// In en, this message translates to:
  /// **'Leave this chat room'**
  String get chatLeaveRoomDescription;

  /// No description provided for @chatLeaveRoomConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this chat?'**
  String get chatLeaveRoomConfirm;

  /// No description provided for @chatRoomLeft.
  ///
  /// In en, this message translates to:
  /// **'Left chat room'**
  String get chatRoomLeft;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @mediaPickImage.
  ///
  /// In en, this message translates to:
  /// **'Pick Image'**
  String get mediaPickImage;

  /// No description provided for @mediaPickVideo.
  ///
  /// In en, this message translates to:
  /// **'Pick Video'**
  String get mediaPickVideo;

  /// No description provided for @mediaPickAudio.
  ///
  /// In en, this message translates to:
  /// **'Pick Audio'**
  String get mediaPickAudio;

  /// No description provided for @mediaPickFile.
  ///
  /// In en, this message translates to:
  /// **'Pick File'**
  String get mediaPickFile;

  /// No description provided for @mediaImageMessage.
  ///
  /// In en, this message translates to:
  /// **'[Image]'**
  String get mediaImageMessage;

  /// No description provided for @mediaVideoMessage.
  ///
  /// In en, this message translates to:
  /// **'[Video]'**
  String get mediaVideoMessage;

  /// No description provided for @mediaAudioMessage.
  ///
  /// In en, this message translates to:
  /// **'[Audio]'**
  String get mediaAudioMessage;

  /// No description provided for @mediaFileMessage.
  ///
  /// In en, this message translates to:
  /// **'[File]'**
  String get mediaFileMessage;

  /// No description provided for @mediaUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get mediaUnknown;

  /// No description provided for @mediaPlayAudio.
  ///
  /// In en, this message translates to:
  /// **'Play Audio'**
  String get mediaPlayAudio;

  /// No description provided for @mediaPauseAudio.
  ///
  /// In en, this message translates to:
  /// **'Pause Audio'**
  String get mediaPauseAudio;

  /// No description provided for @userProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get userProfileTitle;

  /// No description provided for @userProfileUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get userProfileUsername;

  /// No description provided for @userProfileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get userProfileEmail;

  /// No description provided for @userProfileUid.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userProfileUid;

  /// No description provided for @userProfileJoinedAt.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get userProfileJoinedAt;

  /// No description provided for @userProfilePermission.
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get userProfilePermission;

  /// No description provided for @userProfilePermissionAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get userProfilePermissionAdmin;

  /// No description provided for @userProfilePermissionModerator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get userProfilePermissionModerator;

  /// No description provided for @userProfilePermissionUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userProfilePermissionUser;

  /// No description provided for @userProfilePersonalSign.
  ///
  /// In en, this message translates to:
  /// **'Personal Sign'**
  String get userProfilePersonalSign;

  /// No description provided for @userProfileIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get userProfileIntroduction;

  /// No description provided for @userProfileNoPersonalSign.
  ///
  /// In en, this message translates to:
  /// **'No personal sign'**
  String get userProfileNoPersonalSign;

  /// No description provided for @userProfileNoIntroduction.
  ///
  /// In en, this message translates to:
  /// **'No introduction'**
  String get userProfileNoIntroduction;

  /// No description provided for @userProfileCopyUid.
  ///
  /// In en, this message translates to:
  /// **'Copy User ID'**
  String get userProfileCopyUid;

  /// No description provided for @userProfileUidCopied.
  ///
  /// In en, this message translates to:
  /// **'User ID copied'**
  String get userProfileUidCopied;

  /// No description provided for @userProfileSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get userProfileSendMessage;

  /// No description provided for @userProfileLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading profile...'**
  String get userProfileLoading;

  /// No description provided for @userProfileAddFriend.
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get userProfileAddFriend;

  /// No description provided for @userProfileUnknownEmail.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get userProfileUnknownEmail;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutVersionInfo.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({buildNumber})'**
  String aboutVersionInfo(String version, String buildNumber);

  /// No description provided for @aboutAppInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Application Information'**
  String get aboutAppInfoSection;

  /// No description provided for @aboutPackageName.
  ///
  /// In en, this message translates to:
  /// **'Package Name'**
  String get aboutPackageName;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutBuildNumber.
  ///
  /// In en, this message translates to:
  /// **'Build Number'**
  String get aboutBuildNumber;

  /// No description provided for @aboutLinksSection.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get aboutLinksSection;

  /// No description provided for @aboutDocumentation.
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get aboutDocumentation;

  /// No description provided for @aboutServerRepository.
  ///
  /// In en, this message translates to:
  /// **'Backend Server Repository'**
  String get aboutServerRepository;

  /// No description provided for @aboutOpenSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get aboutOpenSourceLicenses;

  /// No description provided for @aboutDeveloperSection.
  ///
  /// In en, this message translates to:
  /// **'Developer Information'**
  String get aboutDeveloperSection;

  /// No description provided for @aboutContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Author'**
  String get aboutContactUs;

  /// No description provided for @aboutSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source Code'**
  String get aboutSourceCode;

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get aboutLicense;

  /// No description provided for @aboutLicenseContent.
  ///
  /// In en, this message translates to:
  /// **'This project is licensed under the AGPLv3 License'**
  String get aboutLicenseContent;

  /// No description provided for @aboutLicenseDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Software License'**
  String get aboutLicenseDialogTitle;

  /// No description provided for @aboutLicenseDescription.
  ///
  /// In en, this message translates to:
  /// **'TouchFish Client is Copyleft free software: you can use, study, share and improve it at any time. You can redistribute or modify it under the GNU Affero General Public License 3.0(AGPLv3) published by the Free Software Foundation.'**
  String get aboutLicenseDescription;

  /// No description provided for @aboutLicenseFullText.
  ///
  /// In en, this message translates to:
  /// **'Full License Text'**
  String get aboutLicenseFullText;

  /// No description provided for @aboutLicenseClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get aboutLicenseClose;

  /// No description provided for @aboutCopyright.
  ///
  /// In en, this message translates to:
  /// **'© {year} ILoveScratch2. All rights reserved.'**
  String aboutCopyright(String year);

  /// No description provided for @aboutMadeWith.
  ///
  /// In en, this message translates to:
  /// **'By ILoveScratch2 & TouchFish Dev Team'**
  String get aboutMadeWith;

  /// No description provided for @aboutCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get aboutCopiedToClipboard;

  /// No description provided for @aboutCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get aboutCopyToClipboard;

  /// No description provided for @aboutEasterEggFound.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You found an easter egg!'**
  String get aboutEasterEggFound;

  /// No description provided for @aboutEasterEggMessage0.
  ///
  /// In en, this message translates to:
  /// **'This is a Easter Egg!'**
  String get aboutEasterEggMessage0;

  /// No description provided for @aboutEasterEggMessage1.
  ///
  /// In en, this message translates to:
  /// **'TouchFish v5, redisigned and reproducted for you!'**
  String get aboutEasterEggMessage1;

  /// No description provided for @aboutEasterEggMessage2.
  ///
  /// In en, this message translates to:
  /// **'TouchFish is developed by XSFX!'**
  String get aboutEasterEggMessage2;

  /// No description provided for @aboutEasterEggMessage3.
  ///
  /// In en, this message translates to:
  /// **'TouchFish is not for touching fish!'**
  String get aboutEasterEggMessage3;

  /// No description provided for @aboutEasterEggMessage4.
  ///
  /// In en, this message translates to:
  /// **'TouchFish Client is free/libre and open source!'**
  String get aboutEasterEggMessage4;

  /// No description provided for @aboutEasterEggMessage5.
  ///
  /// In en, this message translates to:
  /// **''**
  String get aboutEasterEggMessage5;

  /// No description provided for @aboutEasterEggMessage6.
  ///
  /// In en, this message translates to:
  /// **''**
  String get aboutEasterEggMessage6;

  /// No description provided for @aboutEasterEggMessage7.
  ///
  /// In en, this message translates to:
  /// **'TouchFish, LAUNCH!'**
  String get aboutEasterEggMessage7;

  /// No description provided for @aboutEasterEggMessage8.
  ///
  /// In en, this message translates to:
  /// **'Happy TouchFishing!'**
  String get aboutEasterEggMessage8;

  /// No description provided for @aboutEasterEggMessage9.
  ///
  /// In en, this message translates to:
  /// **'TouchFish Client supports Windows, macOS, Linux and Android!'**
  String get aboutEasterEggMessage9;

  /// No description provided for @aboutEasterEggMessage10.
  ///
  /// In en, this message translates to:
  /// **'TouchFish is developed by: XSFX, 035966_L3, Piaoztsdy, JohnChiao75 and many other contributors!'**
  String get aboutEasterEggMessage10;

  /// No description provided for @aboutEasterEggMessage11.
  ///
  /// In en, this message translates to:
  /// **'Taiwan and its affiliated islands have been an inseparable sacred territory of China since ancient times. Adhering to the one-China principle is fundamental. Any external forces and reactionary elements will ultimately be condemned by history. The reunification of Taiwan is an irreversible and unstoppable historical process. Any attempt to split the country is a serious challenge to the fundamental interests of the Chinese nation and the common will of all Chinese people. We firmly safeguard national sovereignty and territorial integrity, adhere to the one-China principle, and oppose any form of \'Taiwan independence\' separatist plot.'**
  String get aboutEasterEggMessage11;

  /// No description provided for @aboutEasterEggMessage12.
  ///
  /// In en, this message translates to:
  /// **'TouchFish Client is open source under AGPLv3 license, TouchFish server is open source under MIT license, welcome to Contribute!'**
  String get aboutEasterEggMessage12;

  /// No description provided for @aboutEasterEggMessage13.
  ///
  /// In en, this message translates to:
  /// **'TouchFish v5 has added new features such as forums, announcements, and multiple chat sessions!'**
  String get aboutEasterEggMessage13;

  /// No description provided for @aboutEasterEggMessage14.
  ///
  /// In en, this message translates to:
  /// **'The dragon steps on the clouds to send messages, and the steed gallops to bring TouchFish'**
  String get aboutEasterEggMessage14;

  /// No description provided for @aboutEasterEggMessage15.
  ///
  /// In en, this message translates to:
  /// **'TouchFish\'s official server address is touchfish.xin, welcome to visit!'**
  String get aboutEasterEggMessage15;

  /// No description provided for @aboutEasterEggMessage16.
  ///
  /// In en, this message translates to:
  /// **'TouchFish delivers messages to every corner!'**
  String get aboutEasterEggMessage16;

  /// No description provided for @aboutEasterEggMessage17.
  ///
  /// In en, this message translates to:
  /// **'It\'s time to touch fish!'**
  String get aboutEasterEggMessage17;

  /// No description provided for @aboutEasterEggMessage18.
  ///
  /// In en, this message translates to:
  /// **'TouchFish, touch the fish!'**
  String get aboutEasterEggMessage18;

  /// No description provided for @aboutEasterEggMessage19.
  ///
  /// In en, this message translates to:
  /// **'YOU ARE SO MAD AT TAPPING??'**
  String get aboutEasterEggMessage19;

  /// No description provided for @aboutEasterEggLevel.
  ///
  /// In en, this message translates to:
  /// **'Easter Egg Level'**
  String get aboutEasterEggLevel;

  /// No description provided for @aboutEasterEggProgress.
  ///
  /// In en, this message translates to:
  /// **'To Lv.{nextLevel}: {remaining} taps'**
  String aboutEasterEggProgress(int nextLevel, int remaining);

  /// No description provided for @aboutEasterEggCompleted.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You\'ve reached the highest level!'**
  String get aboutEasterEggCompleted;

  /// No description provided for @aboutEasterEggLevelName0.
  ///
  /// In en, this message translates to:
  /// **'You will never find this level in app!'**
  String get aboutEasterEggLevelName0;

  /// No description provided for @aboutEasterEggLevelName1.
  ///
  /// In en, this message translates to:
  /// **'TouchFish v1'**
  String get aboutEasterEggLevelName1;

  /// No description provided for @aboutEasterEggLevelName2.
  ///
  /// In en, this message translates to:
  /// **'TouchFish v3'**
  String get aboutEasterEggLevelName2;

  /// No description provided for @aboutEasterEggLevelName3.
  ///
  /// In en, this message translates to:
  /// **'TouchFish v4'**
  String get aboutEasterEggLevelName3;

  /// No description provided for @aboutEasterEggLevelName4.
  ///
  /// In en, this message translates to:
  /// **'TouchFish LTS'**
  String get aboutEasterEggLevelName4;

  /// No description provided for @aboutEasterEggLevelName5.
  ///
  /// In en, this message translates to:
  /// **'TouchFish Plus'**
  String get aboutEasterEggLevelName5;

  /// No description provided for @aboutEasterEggLevelName6.
  ///
  /// In en, this message translates to:
  /// **'TouchFish Pro'**
  String get aboutEasterEggLevelName6;

  /// No description provided for @aboutEasterEggLevelName7.
  ///
  /// In en, this message translates to:
  /// **'TouchFish More'**
  String get aboutEasterEggLevelName7;

  /// No description provided for @aboutEasterEggLevelName8.
  ///
  /// In en, this message translates to:
  /// **'TouchFish UI Remake'**
  String get aboutEasterEggLevelName8;

  /// No description provided for @aboutEasterEggLevelName9.
  ///
  /// In en, this message translates to:
  /// **'TouchFish Astra'**
  String get aboutEasterEggLevelName9;

  /// No description provided for @aboutEasterEggLevelName10.
  ///
  /// In en, this message translates to:
  /// **'TouchFish v5'**
  String get aboutEasterEggLevelName10;

  /// No description provided for @aboutEasterEggLevelName11.
  ///
  /// In en, this message translates to:
  /// **'TouchFish Client'**
  String get aboutEasterEggLevelName11;

  /// No description provided for @aboutEasterEggLevelName12.
  ///
  /// In en, this message translates to:
  /// **'TouchFish UI Remake 2'**
  String get aboutEasterEggLevelName12;

  /// No description provided for @aboutEasterEggLevelName13.
  ///
  /// In en, this message translates to:
  /// **'TouchFish CLI'**
  String get aboutEasterEggLevelName13;

  /// No description provided for @aboutEasterEggLevelName14.
  ///
  /// In en, this message translates to:
  /// **'Xi Shu Fan Xing'**
  String get aboutEasterEggLevelName14;

  /// No description provided for @aboutEasterEggLevelName15.
  ///
  /// In en, this message translates to:
  /// **'TouchFisher!'**
  String get aboutEasterEggLevelName15;

  /// No description provided for @aboutEasterEggReset.
  ///
  /// In en, this message translates to:
  /// **'Reset Progress'**
  String get aboutEasterEggReset;

  /// No description provided for @aboutEasterEggResetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Reset'**
  String get aboutEasterEggResetConfirmTitle;

  /// No description provided for @aboutEasterEggResetConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all easter egg progress? This will reset your level and tap count.'**
  String get aboutEasterEggResetConfirmMessage;

  /// No description provided for @aboutEasterEggResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Progress reset'**
  String get aboutEasterEggResetSuccess;

  /// No description provided for @aboutEasterEggResetCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get aboutEasterEggResetCancel;

  /// No description provided for @aboutEasterEggResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Reset'**
  String get aboutEasterEggResetConfirm;

  /// No description provided for @licensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get licensesTitle;

  /// No description provided for @licensesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search packages...'**
  String get licensesSearchHint;

  /// No description provided for @licensesPackageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} packages'**
  String licensesPackageCount(int count);

  /// No description provided for @licensesNoResults.
  ///
  /// In en, this message translates to:
  /// **'No packages found'**
  String get licensesNoResults;

  /// No description provided for @licensesVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get licensesVersion;

  /// No description provided for @licensesDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get licensesDescription;

  /// No description provided for @licensesLicenseType.
  ///
  /// In en, this message translates to:
  /// **'License Type'**
  String get licensesLicenseType;

  /// No description provided for @licensesLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get licensesLinks;

  /// No description provided for @licensesHomepage.
  ///
  /// In en, this message translates to:
  /// **'Homepage'**
  String get licensesHomepage;

  /// No description provided for @licensesRepository.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get licensesRepository;

  /// No description provided for @licensesLicenseText.
  ///
  /// In en, this message translates to:
  /// **'License Text'**
  String get licensesLicenseText;

  /// No description provided for @licensesLicenseCopied.
  ///
  /// In en, this message translates to:
  /// **'License text copied to clipboard'**
  String get licensesLicenseCopied;

  /// No description provided for @markdownCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get markdownCopyCode;

  /// No description provided for @markdownCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied to clipboard'**
  String get markdownCodeCopied;
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
