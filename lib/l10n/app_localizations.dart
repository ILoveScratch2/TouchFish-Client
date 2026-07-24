import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_och.dart';
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
    Locale('och'),
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

  /// No description provided for @loginErrorEmptyFields.
  ///
  /// In en, this message translates to:
  /// **'Please enter username and password'**
  String get loginErrorEmptyFields;

  /// No description provided for @loginErrorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get loginErrorUserNotFound;

  /// No description provided for @loginErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get loginErrorInvalidCredentials;

  /// No description provided for @loginErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error, please try again'**
  String get loginErrorNetwork;

  /// No description provided for @savedSessionRestoreConnectingTitle.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get savedSessionRestoreConnectingTitle;

  /// No description provided for @savedSessionRestoreConnectingMessage.
  ///
  /// In en, this message translates to:
  /// **'Restoring your saved session and verifying your login. Please wait.'**
  String get savedSessionRestoreConnectingMessage;

  /// No description provided for @savedSessionRestoreFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to use saved session'**
  String get savedSessionRestoreFailedTitle;

  /// No description provided for @savedSessionRestoreFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'This session can\'t be used on the server. Check your network connection or login credentials.'**
  String get savedSessionRestoreFailedMessage;

  /// No description provided for @registerErrorCaptchaRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the captcha'**
  String get registerErrorCaptchaRequired;

  /// No description provided for @registerCaptchaLoad.
  ///
  /// In en, this message translates to:
  /// **'Loading captcha...'**
  String get registerCaptchaLoad;

  /// No description provided for @registerCaptchaCode.
  ///
  /// In en, this message translates to:
  /// **'Captcha'**
  String get registerCaptchaCode;

  /// No description provided for @registerCaptchaRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get registerCaptchaRefresh;

  /// No description provided for @registerErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed, please try again'**
  String get registerErrorFailed;

  /// No description provided for @registerConfirmInfo.
  ///
  /// In en, this message translates to:
  /// **'Confirm your registration details'**
  String get registerConfirmInfo;

  /// No description provided for @registerActivateFailed.
  ///
  /// In en, this message translates to:
  /// **'Activation failed, please check the code'**
  String get registerActivateFailed;

  /// No description provided for @forumLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load forums'**
  String get forumLoadFailed;

  /// No description provided for @forumPostLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load posts'**
  String get forumPostLoadFailed;

  /// No description provided for @forumCommentFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to post comment'**
  String get forumCommentFailed;

  /// No description provided for @forumPostFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to publish post'**
  String get forumPostFailed;

  /// No description provided for @userProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userProfileNotFound;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

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

  /// No description provided for @settingsLanguageCc.
  ///
  /// In en, this message translates to:
  /// **'文言（華夏）'**
  String get settingsLanguageCc;

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

  /// No description provided for @settingsColorCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get settingsColorCustom;

  /// No description provided for @settingsCardOpacityTitle.
  ///
  /// In en, this message translates to:
  /// **'Card Opacity'**
  String get settingsCardOpacityTitle;

  /// No description provided for @settingsCardOpacityDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjust the opacity of card backgrounds'**
  String get settingsCardOpacityDesc;

  /// No description provided for @settingsWindowOpacityTitle.
  ///
  /// In en, this message translates to:
  /// **'Window Transparency'**
  String get settingsWindowOpacityTitle;

  /// No description provided for @settingsWindowOpacityDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjust the transparency of the application window (desktop only)'**
  String get settingsWindowOpacityDesc;

  /// No description provided for @settingsBackgroundImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Background Image'**
  String get settingsBackgroundImageTitle;

  /// No description provided for @settingsBackgroundImageDesc.
  ///
  /// In en, this message translates to:
  /// **'Select the application background image'**
  String get settingsBackgroundImageDesc;

  /// No description provided for @settingsBackgroundImageSelect.
  ///
  /// In en, this message translates to:
  /// **'Select Background Image'**
  String get settingsBackgroundImageSelect;

  /// No description provided for @settingsBackgroundImageClear.
  ///
  /// In en, this message translates to:
  /// **'Clear Background Image'**
  String get settingsBackgroundImageClear;

  /// No description provided for @settingsBackgroundImageGenColor.
  ///
  /// In en, this message translates to:
  /// **'Generate Theme from Background'**
  String get settingsBackgroundImageGenColor;

  /// No description provided for @settingsBackgroundImageGenColorDesc.
  ///
  /// In en, this message translates to:
  /// **'Extract dominant color from background as theme color'**
  String get settingsBackgroundImageGenColorDesc;

  /// No description provided for @settingsBackgroundImageSelectSuccess.
  ///
  /// In en, this message translates to:
  /// **'Background image selected'**
  String get settingsBackgroundImageSelectSuccess;

  /// No description provided for @settingsBackgroundImageClearSuccess.
  ///
  /// In en, this message translates to:
  /// **'Background image cleared'**
  String get settingsBackgroundImageClearSuccess;

  /// No description provided for @settingsBackgroundImageGenColorSuccess.
  ///
  /// In en, this message translates to:
  /// **'Theme colors extracted from background'**
  String get settingsBackgroundImageGenColorSuccess;

  /// No description provided for @settingsBackgroundImageGenColorError.
  ///
  /// In en, this message translates to:
  /// **'Failed to extract colors: {error}'**
  String settingsBackgroundImageGenColorError(String error);

  /// No description provided for @settingsCustomThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Theme Colors'**
  String get settingsCustomThemeTitle;

  /// No description provided for @settingsCustomThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Customize various theme colors of the application'**
  String get settingsCustomThemeDesc;

  /// No description provided for @settingsCustomThemeSeedColor.
  ///
  /// In en, this message translates to:
  /// **'Seed Color'**
  String get settingsCustomThemeSeedColor;

  /// No description provided for @settingsCustomThemePrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary Color'**
  String get settingsCustomThemePrimary;

  /// No description provided for @settingsCustomThemeSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary Color'**
  String get settingsCustomThemeSecondary;

  /// No description provided for @settingsCustomThemeTertiary.
  ///
  /// In en, this message translates to:
  /// **'Tertiary Color'**
  String get settingsCustomThemeTertiary;

  /// No description provided for @settingsCustomThemeSurface.
  ///
  /// In en, this message translates to:
  /// **'Surface Color'**
  String get settingsCustomThemeSurface;

  /// No description provided for @settingsCustomThemeBackground.
  ///
  /// In en, this message translates to:
  /// **'Background Color'**
  String get settingsCustomThemeBackground;

  /// No description provided for @settingsCustomThemeError.
  ///
  /// In en, this message translates to:
  /// **'Error Color'**
  String get settingsCustomThemeError;

  /// No description provided for @settingsCustomThemeReset.
  ///
  /// In en, this message translates to:
  /// **'Reset Custom Colors'**
  String get settingsCustomThemeReset;

  /// No description provided for @settingsCustomThemeResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all custom colors?'**
  String get settingsCustomThemeResetConfirm;

  /// No description provided for @settingsFontFamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get settingsFontFamilyTitle;

  /// No description provided for @settingsFontFamilyDesc.
  ///
  /// In en, this message translates to:
  /// **'Application font family'**
  String get settingsFontFamilyDesc;

  /// No description provided for @settingsFontHarmonyOS.
  ///
  /// In en, this message translates to:
  /// **'HarmonyOS Sans SC (Default, Recommended)'**
  String get settingsFontHarmonyOS;

  /// No description provided for @settingsFontSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get settingsFontSystem;

  /// No description provided for @settingsFontCustomOption.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get settingsFontCustomOption;

  /// No description provided for @settingsCustomFontTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom font'**
  String get settingsCustomFontTitle;

  /// No description provided for @settingsCustomFontDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter the name of the system font to use'**
  String get settingsCustomFontDesc;

  /// No description provided for @settingsCustomFontHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. LXGW WenKai Screen'**
  String get settingsCustomFontHint;

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

  /// No description provided for @serverUseHttps.
  ///
  /// In en, this message translates to:
  /// **'HTTPS'**
  String get serverUseHttps;

  /// No description provided for @serverUseHttpsOn.
  ///
  /// In en, this message translates to:
  /// **'Try encrypted connection (falls back to HTTP)'**
  String get serverUseHttpsOn;

  /// No description provided for @serverUseHttpsOff.
  ///
  /// In en, this message translates to:
  /// **'Use unencrypted connection'**
  String get serverUseHttpsOff;

  /// No description provided for @serverSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get serverSave;

  /// No description provided for @serverTryWss.
  ///
  /// In en, this message translates to:
  /// **'WSS'**
  String get serverTryWss;

  /// No description provided for @serverTryWssOn.
  ///
  /// In en, this message translates to:
  /// **'Try secure WebSocket (falls back to WS)'**
  String get serverTryWssOn;

  /// No description provided for @serverTryWssOff.
  ///
  /// In en, this message translates to:
  /// **'Use unencrypted WebSocket'**
  String get serverTryWssOff;

  /// No description provided for @serverAutoDetectTcpPort.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect TCP Port'**
  String get serverAutoDetectTcpPort;

  /// No description provided for @serverAutoDetectTcpPortDesc.
  ///
  /// In en, this message translates to:
  /// **'Fetch the TCP port from the server automatically'**
  String get serverAutoDetectTcpPortDesc;

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

  /// No description provided for @navAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get navAdmin;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get adminTitle;

  /// No description provided for @adminDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage TouchFish server'**
  String get adminDescription;

  /// No description provided for @adminAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have administrator access.'**
  String get adminAccessDenied;

  /// No description provided for @adminRootOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the root account can manage server settings.'**
  String get adminRootOnly;

  /// No description provided for @adminDefaultAssets.
  ///
  /// In en, this message translates to:
  /// **'Default Images'**
  String get adminDefaultAssets;

  /// No description provided for @adminDefaultAssetsDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload the logo and default avatars used by the server.'**
  String get adminDefaultAssetsDescription;

  /// No description provided for @adminDefaultAssetsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load default images'**
  String get adminDefaultAssetsLoadFailed;

  /// No description provided for @adminDefaultAssetChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Upload PNG'**
  String get adminDefaultAssetChangeAction;

  /// No description provided for @adminDefaultAssetPngHint.
  ///
  /// In en, this message translates to:
  /// **'Only PNG files are accepted by the server.'**
  String get adminDefaultAssetPngHint;

  /// No description provided for @adminDefaultAssetPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get adminDefaultAssetPreviewUnavailable;

  /// No description provided for @adminDefaultAssetLogo.
  ///
  /// In en, this message translates to:
  /// **'Server Logo'**
  String get adminDefaultAssetLogo;

  /// No description provided for @adminDefaultAssetLogoDescription.
  ///
  /// In en, this message translates to:
  /// **'Shown in the app header and server branding surfaces.'**
  String get adminDefaultAssetLogoDescription;

  /// No description provided for @adminDefaultAssetForum.
  ///
  /// In en, this message translates to:
  /// **'Default Forum Image'**
  String get adminDefaultAssetForum;

  /// No description provided for @adminDefaultAssetForumDescription.
  ///
  /// In en, this message translates to:
  /// **'Used when a forum has no custom image.'**
  String get adminDefaultAssetForumDescription;

  /// No description provided for @adminDefaultAssetUser.
  ///
  /// In en, this message translates to:
  /// **'Default User Avatar'**
  String get adminDefaultAssetUser;

  /// No description provided for @adminDefaultAssetUserDescription.
  ///
  /// In en, this message translates to:
  /// **'Used when a user has not uploaded an avatar.'**
  String get adminDefaultAssetUserDescription;

  /// No description provided for @adminDefaultAssetGroup.
  ///
  /// In en, this message translates to:
  /// **'Default Group Avatar'**
  String get adminDefaultAssetGroup;

  /// No description provided for @adminDefaultAssetGroupDescription.
  ///
  /// In en, this message translates to:
  /// **'Used when a group has no custom avatar.'**
  String get adminDefaultAssetGroupDescription;

  /// No description provided for @adminDefaultAssetUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Updated {assetName}.'**
  String adminDefaultAssetUploadSuccess(String assetName);

  /// No description provided for @adminDefaultAssetUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update {assetName}.'**
  String adminDefaultAssetUploadFailed(String assetName);

  /// No description provided for @adminServerSettings.
  ///
  /// In en, this message translates to:
  /// **'Server Settings'**
  String get adminServerSettings;

  /// No description provided for @adminServerSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Update the server name, registration captcha, and key limits.'**
  String get adminServerSettingsDescription;

  /// No description provided for @adminServerSettingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load server settings'**
  String get adminServerSettingsLoadFailed;

  /// No description provided for @adminServerSettingsSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Server settings updated'**
  String get adminServerSettingsSaveSuccess;

  /// No description provided for @adminServerSettingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update server settings'**
  String get adminServerSettingsSaveFailed;

  /// No description provided for @adminServerSettingsInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Please check the server settings form and try again.'**
  String get adminServerSettingsInvalidInput;

  /// No description provided for @adminServerSettingsCaptchaDescription.
  ///
  /// In en, this message translates to:
  /// **'Require a captcha image during registration.'**
  String get adminServerSettingsCaptchaDescription;

  /// No description provided for @adminServerReadOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'These values are returned by the server and cannot be edited here.'**
  String get adminServerReadOnlyDescription;

  /// No description provided for @adminServerFieldServerName.
  ///
  /// In en, this message translates to:
  /// **'Server Name'**
  String get adminServerFieldServerName;

  /// No description provided for @adminServerFieldCaptcha.
  ///
  /// In en, this message translates to:
  /// **'Registration Captcha'**
  String get adminServerFieldCaptcha;

  /// No description provided for @adminServerFieldFileLastTime.
  ///
  /// In en, this message translates to:
  /// **'File Retention Time (hours)'**
  String get adminServerFieldFileLastTime;

  /// No description provided for @adminServerFileLastTimeDescription.
  ///
  /// In en, this message translates to:
  /// **'Must be 0 or greater.'**
  String get adminServerFileLastTimeDescription;

  /// No description provided for @adminServerFieldGroupsLimit.
  ///
  /// In en, this message translates to:
  /// **'Group Limit'**
  String get adminServerFieldGroupsLimit;

  /// No description provided for @adminServerFieldSingleGroupMaxPeople.
  ///
  /// In en, this message translates to:
  /// **'Single Group Max Members'**
  String get adminServerFieldSingleGroupMaxPeople;

  /// No description provided for @adminServerFieldMaxFileSize.
  ///
  /// In en, this message translates to:
  /// **'Max File Size'**
  String get adminServerFieldMaxFileSize;

  /// No description provided for @adminServerFieldMaxMessageLength.
  ///
  /// In en, this message translates to:
  /// **'Max Message Length'**
  String get adminServerFieldMaxMessageLength;

  /// No description provided for @adminServerFieldMaxMessageLengthDescription.
  ///
  /// In en, this message translates to:
  /// **'Maximum characters per message (minimum 1).'**
  String get adminServerFieldMaxMessageLengthDescription;

  /// No description provided for @adminServerFieldApiPort.
  ///
  /// In en, this message translates to:
  /// **'API Port'**
  String get adminServerFieldApiPort;

  /// No description provided for @adminServerFieldTcpPort.
  ///
  /// In en, this message translates to:
  /// **'TCP Port'**
  String get adminServerFieldTcpPort;

  /// No description provided for @adminServerFieldEmailActivation.
  ///
  /// In en, this message translates to:
  /// **'Email Activation'**
  String get adminServerFieldEmailActivation;

  /// No description provided for @adminServerFieldVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verification Email'**
  String get adminServerFieldVerifyEmail;

  /// No description provided for @adminServerUnlimitedHint.
  ///
  /// In en, this message translates to:
  /// **'Use -1 for unlimited.'**
  String get adminServerUnlimitedHint;

  /// No description provided for @adminPendingForums.
  ///
  /// In en, this message translates to:
  /// **'Pending Forums'**
  String get adminPendingForums;

  /// No description provided for @adminPendingForumsDescription.
  ///
  /// In en, this message translates to:
  /// **'Review and approve newly created forums.'**
  String get adminPendingForumsDescription;

  /// No description provided for @adminPendingForumsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No forums are waiting for review.'**
  String get adminPendingForumsEmpty;

  /// No description provided for @adminPendingForumsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load pending forums'**
  String get adminPendingForumsLoadFailed;

  /// No description provided for @adminPendingForumQueueId.
  ///
  /// In en, this message translates to:
  /// **'Queue #{queueId}'**
  String adminPendingForumQueueId(int queueId);

  /// No description provided for @adminPendingForumCreator.
  ///
  /// In en, this message translates to:
  /// **'Creator UID: {uid}'**
  String adminPendingForumCreator(String uid);

  /// No description provided for @adminPendingForumNoIntroduction.
  ///
  /// In en, this message translates to:
  /// **'No introduction provided.'**
  String get adminPendingForumNoIntroduction;

  /// No description provided for @adminApproveForumAction.
  ///
  /// In en, this message translates to:
  /// **'Approve Forum'**
  String get adminApproveForumAction;

  /// No description provided for @adminApproveForumConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve forum'**
  String get adminApproveForumConfirmTitle;

  /// No description provided for @adminApproveForumConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Approve \"{forumName}\" and publish it to the forum list?'**
  String adminApproveForumConfirmMessage(String forumName);

  /// No description provided for @adminApproveForumSuccess.
  ///
  /// In en, this message translates to:
  /// **'Approved \"{forumName}\".'**
  String adminApproveForumSuccess(String forumName);

  /// No description provided for @adminApproveForumFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to approve forum.'**
  String get adminApproveForumFailed;

  /// No description provided for @adminRejectForumAction.
  ///
  /// In en, this message translates to:
  /// **'Reject Forum'**
  String get adminRejectForumAction;

  /// No description provided for @adminRejectForumConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject forum'**
  String get adminRejectForumConfirmTitle;

  /// No description provided for @adminRejectForumConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Reject \"{forumName}\" and remove it from the review queue?'**
  String adminRejectForumConfirmMessage(String forumName);

  /// No description provided for @adminRejectForumSuccess.
  ///
  /// In en, this message translates to:
  /// **'Rejected \"{forumName}\".'**
  String adminRejectForumSuccess(String forumName);

  /// No description provided for @adminRejectForumFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject forum.'**
  String get adminRejectForumFailed;

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

  /// No description provided for @profileEditRemoveAvatar.
  ///
  /// In en, this message translates to:
  /// **'Remove Avatar'**
  String get profileEditRemoveAvatar;

  /// No description provided for @profileEditUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileEditUpdated;

  /// No description provided for @profileEditSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save some changes'**
  String get profileEditSaveFailed;

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

  /// No description provided for @chatInviteAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get chatInviteAccept;

  /// No description provided for @chatInviteReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get chatInviteReject;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationTitle;

  /// No description provided for @notificationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationEmpty;

  /// No description provided for @notificationClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get notificationClearAll;

  /// No description provided for @notificationTabAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get notificationTabAnnouncements;

  /// No description provided for @notificationTabNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationTabNotifications;

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

  /// No description provided for @chatListExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get chatListExpand;

  /// No description provided for @chatListCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get chatListCollapse;

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

  /// No description provided for @connectionBannerConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connectionBannerConnecting;

  /// No description provided for @connectionBannerDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get connectionBannerDisconnected;

  /// No description provided for @connectionBannerConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectionBannerConnected;

  /// No description provided for @connectionBannerTapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get connectionBannerTapToRetry;

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

  /// No description provided for @messageActionRecall.
  ///
  /// In en, this message translates to:
  /// **'Recall'**
  String get messageActionRecall;

  /// No description provided for @messageRecallConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Recall message?'**
  String get messageRecallConfirmTitle;

  /// No description provided for @messageRecallConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the message content for everyone. This action cannot be undone.'**
  String get messageRecallConfirmBody;

  /// No description provided for @messageRecallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not recall the message'**
  String get messageRecallFailed;

  /// No description provided for @messageRecalled.
  ///
  /// In en, this message translates to:
  /// **'Message recalled'**
  String get messageRecalled;

  /// No description provided for @messageQuoteRecalled.
  ///
  /// In en, this message translates to:
  /// **'Recalled message'**
  String get messageQuoteRecalled;

  /// No description provided for @messageQuoteMissing.
  ///
  /// In en, this message translates to:
  /// **'Original message unavailable'**
  String get messageQuoteMissing;

  /// No description provided for @messageReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String messageReplyingTo(String name);

  /// No description provided for @messageReplyDismiss.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get messageReplyDismiss;

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

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

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

  /// No description provided for @filePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get filePreview;

  /// No description provided for @filePreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Preview unavailable'**
  String get filePreviewFailed;

  /// No description provided for @fileDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get fileDownload;

  /// No description provided for @fileDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get fileDownloading;

  /// No description provided for @fileDownloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get fileDownloadStarted;

  /// No description provided for @fileDownloadSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String fileDownloadSaved(String path);

  /// No description provided for @fileDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get fileDownloadFailed;

  /// No description provided for @forumAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get forumAttachments;

  /// No description provided for @forumAttachmentRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get forumAttachmentRemove;

  /// No description provided for @forumAttachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Attachment upload failed'**
  String get forumAttachmentFailed;

  /// No description provided for @settingsAutomaticPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic file previews'**
  String get settingsAutomaticPreviewTitle;

  /// No description provided for @settingsAutomaticPreviewDesc.
  ///
  /// In en, this message translates to:
  /// **'Preview supported files automatically up to this size'**
  String get settingsAutomaticPreviewDesc;

  /// No description provided for @settingsAutomaticPreviewDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsAutomaticPreviewDisabled;

  /// No description provided for @settingsAutomaticPreviewSize.
  ///
  /// In en, this message translates to:
  /// **'{size} MiB'**
  String settingsAutomaticPreviewSize(int size);

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
  /// **'Backend Server'**
  String get aboutServerRepository;

  /// No description provided for @aboutFontLicense.
  ///
  /// In en, this message translates to:
  /// **'Font License'**
  String get aboutFontLicense;

  /// No description provided for @aboutFontLicenseDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'HarmonyOS Sans SC Font License'**
  String get aboutFontLicenseDialogTitle;

  /// No description provided for @aboutFontLicenseDescription.
  ///
  /// In en, this message translates to:
  /// **'This application uses HarmonyOS Sans SC  & LXGW WenKai fonts, provided by Huawei Device Co., Ltd. under the HarmonyOS Sans Fonts License Agreement and LXGW under the SIL Open Font License 1.1. The use of these fonts is subject to their respective license agreements.'**
  String get aboutFontLicenseDescription;

  /// No description provided for @aboutFontLicenseFullText.
  ///
  /// In en, this message translates to:
  /// **'Full License Text'**
  String get aboutFontLicenseFullText;

  /// No description provided for @aboutFontLicenseClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get aboutFontLicenseClose;

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

  /// No description provided for @markdownSpoilerHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get markdownSpoilerHidden;

  /// No description provided for @settingsCorruptedResetNotice.
  ///
  /// In en, this message translates to:
  /// **'Local settings seem corrupted and have been reset.'**
  String get settingsCorruptedResetNotice;

  /// No description provided for @debugLogs.
  ///
  /// In en, this message translates to:
  /// **'Debug Logs'**
  String get debugLogs;

  /// No description provided for @debugLogsDescription.
  ///
  /// In en, this message translates to:
  /// **'View application logs'**
  String get debugLogsDescription;

  /// No description provided for @debugNotificationTester.
  ///
  /// In en, this message translates to:
  /// **'Notification Test'**
  String get debugNotificationTester;

  /// No description provided for @debugNotificationTesterDescription.
  ///
  /// In en, this message translates to:
  /// **'Trigger each in-app and system notification type'**
  String get debugNotificationTesterDescription;

  /// No description provided for @debugNotificationTypePrivateMessage.
  ///
  /// In en, this message translates to:
  /// **'Private Message'**
  String get debugNotificationTypePrivateMessage;

  /// No description provided for @debugNotificationTypeGroupMessage.
  ///
  /// In en, this message translates to:
  /// **'Group Message'**
  String get debugNotificationTypeGroupMessage;

  /// No description provided for @debugNotificationTypeAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get debugNotificationTypeAnnouncement;

  /// No description provided for @debugNotificationTypeForum.
  ///
  /// In en, this message translates to:
  /// **'Forum Notification'**
  String get debugNotificationTypeForum;

  /// No description provided for @debugNotificationTypeInvite.
  ///
  /// In en, this message translates to:
  /// **'Invitation'**
  String get debugNotificationTypeInvite;

  /// No description provided for @debugNotificationTypeGeneral.
  ///
  /// In en, this message translates to:
  /// **'General Notification'**
  String get debugNotificationTypeGeneral;

  /// No description provided for @debugNotificationTestBody.
  ///
  /// In en, this message translates to:
  /// **'This test notification verifies rendering, queueing, and navigation.'**
  String get debugNotificationTestBody;

  /// No description provided for @debugNotificationTestInApp.
  ///
  /// In en, this message translates to:
  /// **'Trigger in-app notification'**
  String get debugNotificationTestInApp;

  /// No description provided for @debugNotificationTestSystem.
  ///
  /// In en, this message translates to:
  /// **'Trigger system notification'**
  String get debugNotificationTestSystem;

  /// No description provided for @debugNotificationSystemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'System notifications are not initialized or supported on this platform.'**
  String get debugNotificationSystemUnavailable;

  /// No description provided for @debugClearMessageDatabase.
  ///
  /// In en, this message translates to:
  /// **'Clear Message Database'**
  String get debugClearMessageDatabase;

  /// No description provided for @debugClearMessageDatabaseDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete all locally cached messages from this client.'**
  String get debugClearMessageDatabaseDescription;

  /// No description provided for @debugClearMessageDatabaseConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Message Database?'**
  String get debugClearMessageDatabaseConfirmTitle;

  /// No description provided for @debugClearMessageDatabaseConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'All locally cached messages will be deleted. Server messages are not affected.'**
  String get debugClearMessageDatabaseConfirmMessage;

  /// No description provided for @debugClearMessageDatabaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Message database cleared.'**
  String get debugClearMessageDatabaseSuccess;

  /// No description provided for @debugCustomInfoDialog.
  ///
  /// In en, this message translates to:
  /// **'Custom Info Dialog'**
  String get debugCustomInfoDialog;

  /// No description provided for @debugCustomInfoDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Preview the reusable info dialog with caller-defined actions'**
  String get debugCustomInfoDialogDescription;

  /// No description provided for @debugCustomErrorDialog.
  ///
  /// In en, this message translates to:
  /// **'Custom Error Dialog'**
  String get debugCustomErrorDialog;

  /// No description provided for @debugCustomErrorDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Preview the reusable error dialog with caller-defined actions'**
  String get debugCustomErrorDialogDescription;

  /// No description provided for @debugInfoDialogDemoTitle.
  ///
  /// In en, this message translates to:
  /// **'Server Profile Updated'**
  String get debugInfoDialogDemoTitle;

  /// No description provided for @debugInfoDialogDemoMessage.
  ///
  /// In en, this message translates to:
  /// **'A refreshed server profile is available. Choose what to do next.'**
  String get debugInfoDialogDemoMessage;

  /// No description provided for @debugErrorDialogDemoTitle.
  ///
  /// In en, this message translates to:
  /// **'Message Sync Failed'**
  String get debugErrorDialogDemoTitle;

  /// No description provided for @debugErrorDialogDemoMessage.
  ///
  /// In en, this message translates to:
  /// **'The current sync task did not finish successfully. You can retry now or open settings to inspect the connection.'**
  String get debugErrorDialogDemoMessage;

  /// No description provided for @debugDialogSelectedAction.
  ///
  /// In en, this message translates to:
  /// **'Selected action: {action}'**
  String debugDialogSelectedAction(String action);

  /// No description provided for @debugMarkdownTester.
  ///
  /// In en, this message translates to:
  /// **'Markdown Test'**
  String get debugMarkdownTester;

  /// No description provided for @debugMarkdownTesterDescription.
  ///
  /// In en, this message translates to:
  /// **'Type Markdown and preview the rendered result'**
  String get debugMarkdownTesterDescription;

  /// No description provided for @debugMarkdownTesterEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Markdown Input'**
  String get debugMarkdownTesterEditorTitle;

  /// No description provided for @debugMarkdownTesterHint.
  ///
  /// In en, this message translates to:
  /// **'Enter Markdown here'**
  String get debugMarkdownTesterHint;

  /// No description provided for @debugMarkdownTesterPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Rendered Preview'**
  String get debugMarkdownTesterPreviewTitle;

  /// No description provided for @debugMarkdownTesterPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'The preview updates as you edit the Markdown source.'**
  String get debugMarkdownTesterPreviewDescription;

  /// No description provided for @debugMarkdownTesterEmptyPreview.
  ///
  /// In en, this message translates to:
  /// **'Rendered content will appear here.'**
  String get debugMarkdownTesterEmptyPreview;

  /// No description provided for @debugApiTester.
  ///
  /// In en, this message translates to:
  /// **'API Test'**
  String get debugApiTester;

  /// No description provided for @debugApiTesterDescription.
  ///
  /// In en, this message translates to:
  /// **'Send API requests to the server and inspect the responses'**
  String get debugApiTesterDescription;

  /// No description provided for @debugApiTesterEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get debugApiTesterEndpoint;

  /// No description provided for @debugApiTesterEndpointHint.
  ///
  /// In en, this message translates to:
  /// **'Example: /auth/login'**
  String get debugApiTesterEndpointHint;

  /// No description provided for @debugApiTesterMethod.
  ///
  /// In en, this message translates to:
  /// **'Request Method'**
  String get debugApiTesterMethod;

  /// No description provided for @debugApiTesterMethodGet.
  ///
  /// In en, this message translates to:
  /// **'GET'**
  String get debugApiTesterMethodGet;

  /// No description provided for @debugApiTesterMethodPost.
  ///
  /// In en, this message translates to:
  /// **'POST'**
  String get debugApiTesterMethodPost;

  /// No description provided for @debugApiTesterUseCredentials.
  ///
  /// In en, this message translates to:
  /// **'Include current login credentials'**
  String get debugApiTesterUseCredentials;

  /// No description provided for @debugApiTesterUseCredentialsDescription.
  ///
  /// In en, this message translates to:
  /// **'Append the current uid and password to the submitted parameters.'**
  String get debugApiTesterUseCredentialsDescription;

  /// No description provided for @debugApiTesterNoCredentials.
  ///
  /// In en, this message translates to:
  /// **'Current login credentials are unavailable.'**
  String get debugApiTesterNoCredentials;

  /// No description provided for @debugApiTesterEncryptRequest.
  ///
  /// In en, this message translates to:
  /// **'Encrypt request body'**
  String get debugApiTesterEncryptRequest;

  /// No description provided for @debugApiTesterEncryptRequestDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, POST requests use the TouchFish encrypted payload format.'**
  String get debugApiTesterEncryptRequestDescription;

  /// No description provided for @debugApiTesterEncryptRequestUnavailableForGet.
  ///
  /// In en, this message translates to:
  /// **'GET requests are sent without encryption.'**
  String get debugApiTesterEncryptRequestUnavailableForGet;

  /// No description provided for @debugApiTesterQueryParameters.
  ///
  /// In en, this message translates to:
  /// **'Query Parameters'**
  String get debugApiTesterQueryParameters;

  /// No description provided for @debugApiTesterQueryParametersHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a JSON object used as GET query parameters'**
  String get debugApiTesterQueryParametersHint;

  /// No description provided for @debugApiTesterRequestBody.
  ///
  /// In en, this message translates to:
  /// **'Request Body'**
  String get debugApiTesterRequestBody;

  /// No description provided for @debugApiTesterRequestBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a JSON object used as the POST request body'**
  String get debugApiTesterRequestBodyHint;

  /// No description provided for @debugApiTesterSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get debugApiTesterSendRequest;

  /// No description provided for @debugApiTesterResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get debugApiTesterResultTitle;

  /// No description provided for @debugApiTesterResultDescription.
  ///
  /// In en, this message translates to:
  /// **'Inspect the submitted parameters and the server response.'**
  String get debugApiTesterResultDescription;

  /// No description provided for @debugApiTesterAwaitingResult.
  ///
  /// In en, this message translates to:
  /// **'Send a request to view the submitted parameters and response.'**
  String get debugApiTesterAwaitingResult;

  /// No description provided for @debugApiTesterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get debugApiTesterStatus;

  /// No description provided for @debugApiTesterStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get debugApiTesterStatusUnavailable;

  /// No description provided for @debugApiTesterRequestUrl.
  ///
  /// In en, this message translates to:
  /// **'Request URL'**
  String get debugApiTesterRequestUrl;

  /// No description provided for @debugApiTesterRequestPayload.
  ///
  /// In en, this message translates to:
  /// **'Request Payload'**
  String get debugApiTesterRequestPayload;

  /// No description provided for @debugApiTesterEncodedBody.
  ///
  /// In en, this message translates to:
  /// **'Encoded Request Body'**
  String get debugApiTesterEncodedBody;

  /// No description provided for @debugApiTesterDecryptedResponse.
  ///
  /// In en, this message translates to:
  /// **'Decrypted Response'**
  String get debugApiTesterDecryptedResponse;

  /// No description provided for @debugApiTesterRawResponse.
  ///
  /// In en, this message translates to:
  /// **'Raw Response'**
  String get debugApiTesterRawResponse;

  /// No description provided for @debugApiTesterError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get debugApiTesterError;

  /// No description provided for @debugApiTesterInvalidEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Please enter an endpoint.'**
  String get debugApiTesterInvalidEndpoint;

  /// No description provided for @debugApiTesterInvalidBody.
  ///
  /// In en, this message translates to:
  /// **'Request body must be a JSON object.'**
  String get debugApiTesterInvalidBody;

  /// No description provided for @debugApiTesterCredentialsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No current login credentials were found.'**
  String get debugApiTesterCredentialsUnavailable;

  /// No description provided for @forumTitle.
  ///
  /// In en, this message translates to:
  /// **'Forum'**
  String get forumTitle;

  /// No description provided for @forumNotFound.
  ///
  /// In en, this message translates to:
  /// **'Forum not found'**
  String get forumNotFound;

  /// No description provided for @forumDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get forumDescription;

  /// No description provided for @forumJoin.
  ///
  /// In en, this message translates to:
  /// **'Join Forum'**
  String get forumJoin;

  /// No description provided for @forumJoinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully joined the forum'**
  String get forumJoinSuccess;

  /// No description provided for @forumLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave Forum'**
  String get forumLeave;

  /// No description provided for @forumLeaveHint.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this forum? You will lose access to forum content.'**
  String get forumLeaveHint;

  /// No description provided for @forumEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Forum'**
  String get forumEdit;

  /// No description provided for @forumDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Forum'**
  String get forumDelete;

  /// No description provided for @forumDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete this forum? This will also delete all the posts under this forum.'**
  String get forumDeleteHint;

  /// No description provided for @forumPinnedPosts.
  ///
  /// In en, this message translates to:
  /// **'Pinned Posts'**
  String get forumPinnedPosts;

  /// No description provided for @forumNoPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get forumNoPosts;

  /// No description provided for @forumPostDetail.
  ///
  /// In en, this message translates to:
  /// **'Post Detail'**
  String get forumPostDetail;

  /// No description provided for @forumPostNotFound.
  ///
  /// In en, this message translates to:
  /// **'Post not found'**
  String get forumPostNotFound;

  /// No description provided for @forumReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get forumReply;

  /// No description provided for @forumReplies.
  ///
  /// In en, this message translates to:
  /// **'{count} replies'**
  String forumReplies(int count);

  /// No description provided for @forumComments.
  ///
  /// In en, this message translates to:
  /// **'{count} comments'**
  String forumComments(int count);

  /// No description provided for @forumNoComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get forumNoComments;

  /// No description provided for @forumCommentPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write a comment...'**
  String get forumCommentPlaceholder;

  /// No description provided for @forumCommentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Comment posted successfully'**
  String get forumCommentSuccess;

  /// No description provided for @forumShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get forumShare;

  /// No description provided for @forumPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get forumPublish;

  /// No description provided for @forumComposePost.
  ///
  /// In en, this message translates to:
  /// **'New Post'**
  String get forumComposePost;

  /// No description provided for @forumComposeReply.
  ///
  /// In en, this message translates to:
  /// **'Reply to Post'**
  String get forumComposeReply;

  /// No description provided for @forumPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get forumPostTitle;

  /// No description provided for @forumPostTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get forumPostTitleRequired;

  /// No description provided for @forumPostContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get forumPostContent;

  /// No description provided for @forumPostContentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter content'**
  String get forumPostContentRequired;

  /// No description provided for @forumPostContentMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Supports Markdown formatting'**
  String get forumPostContentMarkdown;

  /// No description provided for @forumPostSuccess.
  ///
  /// In en, this message translates to:
  /// **'Post published successfully'**
  String get forumPostSuccess;

  /// No description provided for @forumReplySuccess.
  ///
  /// In en, this message translates to:
  /// **'Reply posted successfully'**
  String get forumReplySuccess;

  /// No description provided for @forumMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String forumMembersCount(int count);

  /// No description provided for @forumInviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite Member'**
  String get forumInviteMember;

  /// No description provided for @forumRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Remove Member'**
  String get forumRemoveMember;

  /// No description provided for @forumRemoveMemberHint.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to remove this member?'**
  String get forumRemoveMemberHint;

  /// No description provided for @forumMemberRoleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit role of {name}'**
  String forumMemberRoleEdit(String name);

  /// No description provided for @forumMemberRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get forumMemberRole;

  /// No description provided for @forumMemberRoleHint.
  ///
  /// In en, this message translates to:
  /// **'0=Member, 50=Admin, 100=Owner'**
  String get forumMemberRoleHint;

  /// No description provided for @forumRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get forumRoleOwner;

  /// No description provided for @forumRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get forumRoleAdmin;

  /// No description provided for @forumRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get forumRoleMember;

  /// No description provided for @forumTabJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get forumTabJoined;

  /// No description provided for @forumTabExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get forumTabExplore;

  /// No description provided for @forumNoJoined.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t joined any forums yet'**
  String get forumNoJoined;

  /// No description provided for @forumPostDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get forumPostDescription;

  /// No description provided for @forumComposeAttachImage.
  ///
  /// In en, this message translates to:
  /// **'Attach image'**
  String get forumComposeAttachImage;

  /// No description provided for @forumComposeAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get forumComposeAttachFile;

  /// No description provided for @forumCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get forumCopyLink;

  /// No description provided for @forumCommentSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get forumCommentSend;

  /// No description provided for @forumExpandEditor.
  ///
  /// In en, this message translates to:
  /// **'Expand editor'**
  String get forumExpandEditor;

  /// No description provided for @forumMdBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get forumMdBold;

  /// No description provided for @forumMdItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get forumMdItalic;

  /// No description provided for @forumMdStrikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get forumMdStrikethrough;

  /// No description provided for @forumMdHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get forumMdHeading;

  /// No description provided for @forumMdList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get forumMdList;

  /// No description provided for @forumMdQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get forumMdQuote;

  /// No description provided for @forumMdCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get forumMdCode;

  /// No description provided for @forumMdLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get forumMdLink;

  /// No description provided for @forumCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Forum'**
  String get forumCreateTitle;

  /// No description provided for @forumCreateTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Forum name'**
  String get forumCreateTitleHint;

  /// No description provided for @forumCreateDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get forumCreateDescriptionHint;

  /// No description provided for @forumCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Forum submitted for review'**
  String get forumCreateSuccess;

  /// No description provided for @forumCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create forum'**
  String get forumCreateFailed;

  /// No description provided for @forumPinPost.
  ///
  /// In en, this message translates to:
  /// **'Pin Post'**
  String get forumPinPost;

  /// No description provided for @forumUnpinPost.
  ///
  /// In en, this message translates to:
  /// **'Unpin Post'**
  String get forumUnpinPost;

  /// No description provided for @forumDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Forum deleted successfully'**
  String get forumDeleteSuccess;

  /// No description provided for @forumDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete forum'**
  String get forumDeleteFailed;

  /// No description provided for @announcementTitle.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcementTitle;

  /// No description provided for @announcementNoAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'No announcements yet'**
  String get announcementNoAnnouncements;

  /// No description provided for @announcementCreate.
  ///
  /// In en, this message translates to:
  /// **'New Announcement'**
  String get announcementCreate;

  /// No description provided for @announcementCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Write announcement content...'**
  String get announcementCreateHint;

  /// No description provided for @announcementCreateEmpty.
  ///
  /// In en, this message translates to:
  /// **'Content cannot be empty'**
  String get announcementCreateEmpty;

  /// No description provided for @announcementCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Announcement created'**
  String get announcementCreateSuccess;

  /// No description provided for @announcementCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create announcement'**
  String get announcementCreateFailed;

  /// No description provided for @announcementDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this announcement?'**
  String get announcementDeleteConfirm;

  /// No description provided for @announcementDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Announcement deleted'**
  String get announcementDeleteSuccess;

  /// No description provided for @announcementDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete announcement'**
  String get announcementDeleteFailed;

  /// No description provided for @adminAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get adminAnnouncements;

  /// No description provided for @adminAnnouncementsDescription.
  ///
  /// In en, this message translates to:
  /// **'Create and manage system announcements'**
  String get adminAnnouncementsDescription;

  /// No description provided for @adminAccountManagement.
  ///
  /// In en, this message translates to:
  /// **'Account Management'**
  String get adminAccountManagement;

  /// No description provided for @adminAccountManagementDescription.
  ///
  /// In en, this message translates to:
  /// **'View and manage user accounts'**
  String get adminAccountManagementDescription;

  /// No description provided for @adminAccountLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load users'**
  String get adminAccountLoadFailed;

  /// No description provided for @adminAccountEmpty.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get adminAccountEmpty;

  /// No description provided for @adminAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Created: {date}'**
  String adminAccountCreated(String date);

  /// No description provided for @adminAccountChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change Role'**
  String get adminAccountChangeRole;

  /// No description provided for @adminAccountChangeRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Change role of {name}'**
  String adminAccountChangeRoleTitle(String name);

  /// No description provided for @adminAccountCurrentRole.
  ///
  /// In en, this message translates to:
  /// **'Current role'**
  String get adminAccountCurrentRole;

  /// No description provided for @adminAccountRoleRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get adminAccountRoleRoot;

  /// No description provided for @adminAccountRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminAccountRoleAdmin;

  /// No description provided for @adminAccountRoleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get adminAccountRoleUser;

  /// No description provided for @adminAccountRoleBanned.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get adminAccountRoleBanned;

  /// No description provided for @adminAccountRoleChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change role'**
  String get adminAccountRoleChangeFailed;

  /// No description provided for @adminAccountRoleChangeSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name}: role changed to {role}'**
  String adminAccountRoleChangeSuccess(String name, String role);

  /// No description provided for @adminAccountBanTitle.
  ///
  /// In en, this message translates to:
  /// **'Ban User'**
  String get adminAccountBanTitle;

  /// No description provided for @adminAccountBanAction.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get adminAccountBanAction;

  /// No description provided for @adminAccountBanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Ban {name}? They will be unable to log in.'**
  String adminAccountBanConfirm(String name);

  /// No description provided for @adminAccountBanSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} has been banned'**
  String adminAccountBanSuccess(String name);

  /// No description provided for @adminAccountBanFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to ban user'**
  String get adminAccountBanFailed;

  /// No description provided for @adminAccountUnbanTitle.
  ///
  /// In en, this message translates to:
  /// **'Unban User'**
  String get adminAccountUnbanTitle;

  /// No description provided for @adminAccountUnbanAction.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get adminAccountUnbanAction;

  /// No description provided for @adminAccountUnbanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Unban {name}?'**
  String adminAccountUnbanConfirm(String name);

  /// No description provided for @adminAccountUnbanSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} has been unbanned'**
  String adminAccountUnbanSuccess(String name);

  /// No description provided for @adminAccountUnbanFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to unban user'**
  String get adminAccountUnbanFailed;

  /// No description provided for @adminAccountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get adminAccountDeleteTitle;

  /// No description provided for @adminAccountDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get adminAccountDeleteAction;

  /// No description provided for @adminAccountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {name}? This action cannot be undone.'**
  String adminAccountDeleteConfirm(String name);

  /// No description provided for @adminAccountDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} has been deleted'**
  String adminAccountDeleteSuccess(String name);

  /// No description provided for @adminAccountDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete user'**
  String get adminAccountDeleteFailed;

  /// No description provided for @adminAccountTotalUsers.
  ///
  /// In en, this message translates to:
  /// **'users'**
  String get adminAccountTotalUsers;

  /// No description provided for @storageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage Management'**
  String get storageTitle;

  /// No description provided for @storageUploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get storageUploadFile;

  /// No description provided for @storageRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get storageRefresh;

  /// No description provided for @storageNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get storageNotLoggedIn;

  /// No description provided for @storageNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files uploaded'**
  String get storageNoFiles;

  /// No description provided for @storageDeleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get storageDeleteFile;

  /// No description provided for @storageDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{fileName}\"? This action cannot be undone.'**
  String storageDeleteConfirm(String fileName);

  /// No description provided for @storageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted: {fileName}'**
  String storageDeleted(String fileName);

  /// No description provided for @storageDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get storageDeleteFailed;

  /// No description provided for @storageUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded: {fileName}'**
  String storageUploaded(String fileName);

  /// No description provided for @storageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get storageUploadFailed;

  /// No description provided for @storageUploadError.
  ///
  /// In en, this message translates to:
  /// **'Upload error'**
  String get storageUploadError;

  /// No description provided for @storageCouldNotReadFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read file'**
  String get storageCouldNotReadFile;

  /// No description provided for @storageFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large, max {size} MB'**
  String storageFileTooLarge(int size);

  /// No description provided for @storageUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get storageUsed;

  /// No description provided for @storageUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get storageUnlimited;

  /// No description provided for @storageRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get storageRetry;

  /// No description provided for @adminFileManagement.
  ///
  /// In en, this message translates to:
  /// **'File Management'**
  String get adminFileManagement;

  /// No description provided for @adminFileManagementDescription.
  ///
  /// In en, this message translates to:
  /// **'View all uploaded files, filter by user, and force delete files.'**
  String get adminFileManagementDescription;

  /// No description provided for @adminFileFilterUid.
  ///
  /// In en, this message translates to:
  /// **'Filter by User ID...'**
  String get adminFileFilterUid;

  /// No description provided for @adminFileFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get adminFileFilter;

  /// No description provided for @adminFileFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get adminFileFilterClear;

  /// No description provided for @adminFileForceDelete.
  ///
  /// In en, this message translates to:
  /// **'Force Delete'**
  String get adminFileForceDelete;

  /// No description provided for @adminFileForceDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Force Delete File'**
  String get adminFileForceDeleteTitle;

  /// No description provided for @adminFileForceDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete \"{fileName}\" (owner: {owner})?\n\nThis removes the file from disk and database regardless of references.'**
  String adminFileForceDeleteConfirm(String fileName, String owner);

  /// No description provided for @adminFileForceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Force deleted: {fileName}'**
  String adminFileForceDeleted(String fileName);

  /// No description provided for @adminFileForceDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Force delete failed'**
  String get adminFileForceDeleteFailed;

  /// No description provided for @adminFileNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files on server'**
  String get adminFileNoFiles;

  /// No description provided for @adminFileNoFilesForUid.
  ///
  /// In en, this message translates to:
  /// **'No files found for UID {uid}'**
  String adminFileNoFilesForUid(String uid);

  /// No description provided for @adminFileSummaryFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get adminFileSummaryFiles;

  /// No description provided for @adminFileSummaryUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminFileSummaryUsers;

  /// No description provided for @adminFileSummaryTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get adminFileSummaryTotal;

  /// No description provided for @chatFunctionTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get chatFunctionTabFiles;

  /// No description provided for @chatFunctionTabEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get chatFunctionTabEmoji;

  /// No description provided for @chatFunctionTabSpecial.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get chatFunctionTabSpecial;

  /// No description provided for @chatFunctionTabFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Select files to send'**
  String get chatFunctionTabFilesHint;

  /// No description provided for @chatFunctionTabEmojiHint.
  ///
  /// In en, this message translates to:
  /// **'Emoji picker coming soon'**
  String get chatFunctionTabEmojiHint;

  /// No description provided for @chatFunctionTabSpecialHint.
  ///
  /// In en, this message translates to:
  /// **'Special messages coming soon'**
  String get chatFunctionTabSpecialHint;

  /// No description provided for @chatFunctionPickFile.
  ///
  /// In en, this message translates to:
  /// **'Pick File'**
  String get chatFunctionPickFile;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed'**
  String get chatSendFailed;

  /// No description provided for @chatCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get chatCreateGroup;

  /// No description provided for @chatAddFriend.
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get chatAddFriend;

  /// No description provided for @chatAddFriendHint.
  ///
  /// In en, this message translates to:
  /// **'Enter username or UID'**
  String get chatAddFriendHint;

  /// No description provided for @chatSendFailedBanned.
  ///
  /// In en, this message translates to:
  /// **'You have been banned and cannot send messages'**
  String get chatSendFailedBanned;

  /// No description provided for @chatSendFailedRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You are sending messages too fast'**
  String get chatSendFailedRateLimited;

  /// No description provided for @chatSendFailedNotFriends.
  ///
  /// In en, this message translates to:
  /// **'You are not friends with this user'**
  String get chatSendFailedNotFriends;

  /// No description provided for @chatSendFailedNotGroupMember.
  ///
  /// In en, this message translates to:
  /// **'You are not a member of this group'**
  String get chatSendFailedNotGroupMember;

  /// No description provided for @chatSendFailedTooLong.
  ///
  /// In en, this message translates to:
  /// **'Message is too long'**
  String get chatSendFailedTooLong;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupNameLabel;

  /// No description provided for @groupIntroLabel.
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get groupIntroLabel;

  /// No description provided for @groupEnterHintLabel.
  ///
  /// In en, this message translates to:
  /// **'Join Hint'**
  String get groupEnterHintLabel;

  /// No description provided for @groupEnterHintHelp.
  ///
  /// In en, this message translates to:
  /// **'Shown at the top of the chat after members join'**
  String get groupEnterHintHelp;

  /// No description provided for @groupEnterHintUpdated.
  ///
  /// In en, this message translates to:
  /// **'Join hint updated'**
  String get groupEnterHintUpdated;

  /// No description provided for @groupManagement.
  ///
  /// In en, this message translates to:
  /// **'Group Management'**
  String get groupManagement;

  /// No description provided for @groupOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Group'**
  String get groupOpen;

  /// No description provided for @groupCreateNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Group name cannot be empty'**
  String get groupCreateNameEmpty;

  /// No description provided for @groupCreateNameLength.
  ///
  /// In en, this message translates to:
  /// **'Group name must be {minLen} to {maxLen} characters'**
  String groupCreateNameLength(int minLen, int maxLen);

  /// No description provided for @groupCreateFailedLimit.
  ///
  /// In en, this message translates to:
  /// **'Creation failed, check group count limit'**
  String get groupCreateFailedLimit;

  /// No description provided for @groupSettingsSection.
  ///
  /// In en, this message translates to:
  /// **'Group Settings'**
  String get groupSettingsSection;

  /// No description provided for @groupMembersSection.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupMembersSection;

  /// No description provided for @groupJoinRequestsSection.
  ///
  /// In en, this message translates to:
  /// **'Join Requests'**
  String get groupJoinRequestsSection;

  /// No description provided for @groupAllowDirectJoin.
  ///
  /// In en, this message translates to:
  /// **'Allow direct join'**
  String get groupAllowDirectJoin;

  /// No description provided for @groupAllowDirectJoinDesc.
  ///
  /// In en, this message translates to:
  /// **'Non-members can request to join'**
  String get groupAllowDirectJoinDesc;

  /// No description provided for @groupRequireReview.
  ///
  /// In en, this message translates to:
  /// **'Require review'**
  String get groupRequireReview;

  /// No description provided for @groupRequireReviewDesc.
  ///
  /// In en, this message translates to:
  /// **'Join requests require owner approval'**
  String get groupRequireReviewDesc;

  /// No description provided for @groupTransferOwner.
  ///
  /// In en, this message translates to:
  /// **'Transfer Ownership'**
  String get groupTransferOwner;

  /// No description provided for @groupTransferOwnerConfirm.
  ///
  /// In en, this message translates to:
  /// **'After transfer, you will lose owner permissions. Continue?'**
  String get groupTransferOwnerConfirm;

  /// No description provided for @groupTransferOwnerConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm Transfer'**
  String get groupTransferOwnerConfirmAction;

  /// No description provided for @groupSelectNewOwner.
  ///
  /// In en, this message translates to:
  /// **'Select New Owner'**
  String get groupSelectNewOwner;

  /// No description provided for @groupLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get groupLeave;

  /// No description provided for @groupLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this group?'**
  String get groupLeaveConfirm;

  /// No description provided for @groupLeaveOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership before leaving the group'**
  String get groupLeaveOwnerHint;

  /// No description provided for @groupInviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite Member'**
  String get groupInviteMember;

  /// No description provided for @groupInviteMemberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter username or UID of friend'**
  String get groupInviteMemberHint;

  /// No description provided for @groupInvitePendingReview.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent, pending review'**
  String get groupInvitePendingReview;

  /// No description provided for @groupInviteJoined.
  ///
  /// In en, this message translates to:
  /// **'Invited to group'**
  String get groupInviteJoined;

  /// No description provided for @groupInviteFailed.
  ///
  /// In en, this message translates to:
  /// **'Invitation failed. Make sure the user exists and is your friend'**
  String get groupInviteFailed;

  /// No description provided for @groupAvatarPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Only owner or admin can change group avatar'**
  String get groupAvatarPermissionDenied;

  /// No description provided for @groupAvatarUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group avatar updated'**
  String get groupAvatarUpdateSuccess;

  /// No description provided for @groupAvatarUploadFailedSize.
  ///
  /// In en, this message translates to:
  /// **'Upload failed, check file size'**
  String get groupAvatarUploadFailedSize;

  /// No description provided for @groupJoinDirectRequest.
  ///
  /// In en, this message translates to:
  /// **'Direct join request'**
  String get groupJoinDirectRequest;

  /// No description provided for @groupJoinInvitedBy.
  ///
  /// In en, this message translates to:
  /// **'Invited by {name}'**
  String groupJoinInvitedBy(String name);

  /// No description provided for @groupRemoveAdmin.
  ///
  /// In en, this message translates to:
  /// **'Remove Admin'**
  String get groupRemoveAdmin;

  /// No description provided for @groupSetAdmin.
  ///
  /// In en, this message translates to:
  /// **'Set as Admin'**
  String get groupSetAdmin;

  /// No description provided for @groupRemoveMemberAction.
  ///
  /// In en, this message translates to:
  /// **'Remove from Group'**
  String get groupRemoveMemberAction;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonMe.
  ///
  /// In en, this message translates to:
  /// **'(me)'**
  String get commonMe;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonFailedOperation.
  ///
  /// In en, this message translates to:
  /// **'Operation failed, please retry'**
  String get commonFailedOperation;

  /// No description provided for @commonUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get commonUserNotFound;

  /// No description provided for @commonFileReadError.
  ///
  /// In en, this message translates to:
  /// **'Cannot read file'**
  String get commonFileReadError;

  /// No description provided for @chatLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get chatLoading;

  /// No description provided for @chatInputNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected to chat server'**
  String get chatInputNotConnected;

  /// No description provided for @chatInviteAcceptFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to accept friend request'**
  String get chatInviteAcceptFailed;

  /// No description provided for @chatInviteRejectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject friend request'**
  String get chatInviteRejectFailed;

  /// No description provided for @userProfileFriendRequestHint.
  ///
  /// In en, this message translates to:
  /// **'Say hello...'**
  String get userProfileFriendRequestHint;

  /// No description provided for @userProfileFriendRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Friend request sent to {username}'**
  String userProfileFriendRequestSent(String username);

  /// No description provided for @userProfileFriendRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send friend request'**
  String get userProfileFriendRequestFailed;
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
      <String>['en', 'och', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'och':
      return AppLocalizationsOch();
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
