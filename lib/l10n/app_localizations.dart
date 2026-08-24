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

  /// No description provided for @settingsCategoryDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get settingsCategoryDrafts;

  /// No description provided for @settingsSaveChatDraftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Chat Drafts'**
  String get settingsSaveChatDraftsTitle;

  /// No description provided for @settingsSaveChatDraftsDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically save unsent text in each chat. Turning this off clears chat drafts for the current server and account.'**
  String get settingsSaveChatDraftsDesc;

  /// No description provided for @settingsSaveForumDraftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Forum Drafts'**
  String get settingsSaveForumDraftsTitle;

  /// No description provided for @settingsSaveForumDraftsDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically save forum creation, post, comment, and attachment drafts. Turning this off clears forum drafts for the current server and account.'**
  String get settingsSaveForumDraftsDesc;

  /// No description provided for @settingsCategoryAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsCategoryAbout;

  /// No description provided for @settingsCategorySecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsCategorySecurity;

  /// No description provided for @settingsSecurityMasterPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Master Password'**
  String get settingsSecurityMasterPasswordTitle;

  /// No description provided for @settingsSecurityMasterPasswordDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlock the app with a master password.'**
  String get settingsSecurityMasterPasswordDesc;

  /// No description provided for @settingsSecuritySetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set Master Password'**
  String get settingsSecuritySetPassword;

  /// No description provided for @settingsSecurityChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Master Password'**
  String get settingsSecurityChangePassword;

  /// No description provided for @settingsSecurityCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Master Password'**
  String get settingsSecurityCurrentPassword;

  /// No description provided for @settingsSecurityConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Master Password'**
  String get settingsSecurityConfirmPassword;

  /// No description provided for @settingsSecurityPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Master password must be at least 4 characters'**
  String get settingsSecurityPasswordTooShort;

  /// No description provided for @settingsSecurityPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords do not match'**
  String get settingsSecurityPasswordMismatch;

  /// No description provided for @settingsSecurityPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'Master password set'**
  String get settingsSecurityPasswordSet;

  /// No description provided for @settingsSecurityPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Master password changed'**
  String get settingsSecurityPasswordChanged;

  /// No description provided for @settingsSecurityPasswordDisabled.
  ///
  /// In en, this message translates to:
  /// **'Master password disabled'**
  String get settingsSecurityPasswordDisabled;

  /// No description provided for @settingsSecurityPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect master password'**
  String get settingsSecurityPasswordIncorrect;

  /// No description provided for @settingsSecurityDisablePassword.
  ///
  /// In en, this message translates to:
  /// **'Disable Master Password'**
  String get settingsSecurityDisablePassword;

  /// No description provided for @settingsSecurityDisablePasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Disable the master password? This also disables biometric unlock and the app will no longer be locked.'**
  String get settingsSecurityDisablePasswordConfirm;

  /// No description provided for @settingsSecurityBiometricTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric Unlock'**
  String get settingsSecurityBiometricTitle;

  /// No description provided for @settingsSecurityBiometricDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlock the app with fingerprint or face on supported devices'**
  String get settingsSecurityBiometricDesc;

  /// No description provided for @settingsSecurityBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are unavailable on this device'**
  String get settingsSecurityBiometricUnavailable;

  /// No description provided for @settingsSecurityBiometricCancelled.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication was cancelled'**
  String get settingsSecurityBiometricCancelled;

  /// No description provided for @settingsSecurityBiometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to enable biometric unlock'**
  String get settingsSecurityBiometricFailed;

  /// No description provided for @settingsSecurityLockNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock Now'**
  String get settingsSecurityLockNowTitle;

  /// No description provided for @settingsSecurityLockNowDesc.
  ///
  /// In en, this message translates to:
  /// **'Lock the app immediately; a master password or biometrics is required to unlock'**
  String get settingsSecurityLockNowDesc;

  /// No description provided for @settingsShowOnLockScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Above Lock Screen'**
  String get settingsShowOnLockScreenTitle;

  /// No description provided for @settingsShowOnLockScreenDesc.
  ///
  /// In en, this message translates to:
  /// **'When enabled the app can appear above the Android lock screen, letting you view and use content without unlocking (some systems may restrict typing or secure actions)'**
  String get settingsShowOnLockScreenDesc;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'TouchFish is locked'**
  String get lockTitle;

  /// No description provided for @lockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your master password to unlock'**
  String get lockSubtitle;

  /// No description provided for @lockPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Master Password'**
  String get lockPasswordLabel;

  /// No description provided for @lockPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your master password'**
  String get lockPasswordRequired;

  /// No description provided for @lockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockUnlock;

  /// No description provided for @lockBiometricAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get lockBiometricAction;

  /// No description provided for @lockErrorInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect master password'**
  String get lockErrorInvalidPassword;

  /// No description provided for @lockErrorBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are unavailable on this device'**
  String get lockErrorBiometricUnavailable;

  /// No description provided for @lockErrorBiometricCancelled.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication was cancelled'**
  String get lockErrorBiometricCancelled;

  /// No description provided for @lockErrorBiometricNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock is not enabled'**
  String get lockErrorBiometricNotEnabled;

  /// No description provided for @lockErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unlock failed, please try again'**
  String get lockErrorUnknown;

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

  /// No description provided for @settingsCloseToTrayTitle.
  ///
  /// In en, this message translates to:
  /// **'Minimize to Tray on Close'**
  String get settingsCloseToTrayTitle;

  /// No description provided for @settingsCloseToTrayDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep running in the background when the window is closed instead of quitting (desktop only)'**
  String get settingsCloseToTrayDesc;

  /// No description provided for @trayShowApp.
  ///
  /// In en, this message translates to:
  /// **'Open TouchFish'**
  String get trayShowApp;

  /// No description provided for @trayHideWindow.
  ///
  /// In en, this message translates to:
  /// **'Hide Window'**
  String get trayHideWindow;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @trayLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get trayLock;

  /// No description provided for @trayTooltip.
  ///
  /// In en, this message translates to:
  /// **'TouchFish Client'**
  String get trayTooltip;

  /// No description provided for @titleBarMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get titleBarMinimize;

  /// No description provided for @titleBarMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get titleBarMaximize;

  /// No description provided for @titleBarRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get titleBarRestore;

  /// No description provided for @titleBarClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get titleBarClose;

  /// No description provided for @imageZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get imageZoomIn;

  /// No description provided for @imageZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get imageZoomOut;

  /// No description provided for @imageRotateLeft.
  ///
  /// In en, this message translates to:
  /// **'Rotate left'**
  String get imageRotateLeft;

  /// No description provided for @imageRotateRight.
  ///
  /// In en, this message translates to:
  /// **'Rotate right'**
  String get imageRotateRight;

  /// No description provided for @imageExif.
  ///
  /// In en, this message translates to:
  /// **'View EXIF info'**
  String get imageExif;

  /// No description provided for @announcementEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Announcement'**
  String get announcementEdit;

  /// No description provided for @announcementDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete announcement'**
  String get announcementDelete;

  /// No description provided for @chatSelectPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select a chat to start talking'**
  String get chatSelectPlaceholder;

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

  /// No description provided for @settingsNotificationLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Level'**
  String get settingsNotificationLevelTitle;

  /// No description provided for @settingsNotificationLevelDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose how banner notifications are displayed. Notification list is unaffected'**
  String get settingsNotificationLevelDesc;

  /// No description provided for @settingsNotificationLevelMinimal.
  ///
  /// In en, this message translates to:
  /// **'Level 1: Summary only'**
  String get settingsNotificationLevelMinimal;

  /// No description provided for @settingsNotificationLevelPerSender.
  ///
  /// In en, this message translates to:
  /// **'Level 2: Per sender (default)'**
  String get settingsNotificationLevelPerSender;

  /// No description provided for @settingsNotificationLevelFull.
  ///
  /// In en, this message translates to:
  /// **'Level 3: Show all'**
  String get settingsNotificationLevelFull;

  /// No description provided for @notificationLevelSummary.
  ///
  /// In en, this message translates to:
  /// **'{contacts} contacts sent {messages} messages'**
  String notificationLevelSummary(int contacts, int messages);

  /// No description provided for @notificationReplyAction.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get notificationReplyAction;

  /// No description provided for @notificationReplyInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type your reply'**
  String get notificationReplyInputHint;

  /// No description provided for @notificationSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'TouchFish Messages'**
  String get notificationSummaryTitle;

  /// No description provided for @notificationSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'New chat messages'**
  String get notificationSummarySubtitle;

  /// No description provided for @notificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'TouchFish notifications'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Messages and activity from TouchFish'**
  String get notificationChannelDesc;

  /// No description provided for @notificationOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open notification'**
  String get notificationOpenAction;

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

  /// No description provided for @adminServerFieldDefaultJoinTargets.
  ///
  /// In en, this message translates to:
  /// **'Default Friends and Groups'**
  String get adminServerFieldDefaultJoinTargets;

  /// No description provided for @adminServerFieldDefaultJoinTargetsDescription.
  ///
  /// In en, this message translates to:
  /// **'New users automatically become friends with U targets and join G targets. Separate multiple values with spaces, commas, or new lines, for example: U1 U2 G1.'**
  String get adminServerFieldDefaultJoinTargetsDescription;

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

  /// No description provided for @adminServerSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get adminServerSectionGeneral;

  /// No description provided for @adminServerSectionMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get adminServerSectionMessages;

  /// No description provided for @adminServerSectionFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get adminServerSectionFiles;

  /// No description provided for @adminServerSectionGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get adminServerSectionGroups;

  /// No description provided for @adminServerSectionStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get adminServerSectionStickers;

  /// No description provided for @adminServerFieldMaxStickerPacks.
  ///
  /// In en, this message translates to:
  /// **'Sticker packs per user'**
  String get adminServerFieldMaxStickerPacks;

  /// No description provided for @adminServerFieldMaxStickersPerPack.
  ///
  /// In en, this message translates to:
  /// **'Stickers per pack'**
  String get adminServerFieldMaxStickersPerPack;

  /// No description provided for @adminServerFieldMaxStickerSize.
  ///
  /// In en, this message translates to:
  /// **'Max sticker size (bytes, -1 unlimited)'**
  String get adminServerFieldMaxStickerSize;

  /// No description provided for @adminServerFieldDailyStickerPackLimit.
  ///
  /// In en, this message translates to:
  /// **'Daily pack creation limit'**
  String get adminServerFieldDailyStickerPackLimit;

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

  /// No description provided for @adminServerSectionAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced Configuration'**
  String get adminServerSectionAdvanced;

  /// No description provided for @adminServerSectionEmailService.
  ///
  /// In en, this message translates to:
  /// **'Email Verification Service'**
  String get adminServerSectionEmailService;

  /// No description provided for @adminServerEmailDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, new users must provide an email and activate their account with a verification code.'**
  String get adminServerEmailDescription;

  /// No description provided for @adminServerEmailEnableDescription.
  ///
  /// In en, this message translates to:
  /// **'Send a verification code to the user\'s email during registration.'**
  String get adminServerEmailEnableDescription;

  /// No description provided for @adminServerFieldSmtpHost.
  ///
  /// In en, this message translates to:
  /// **'SMTP Server Address'**
  String get adminServerFieldSmtpHost;

  /// No description provided for @adminServerSmtpHostDescription.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to auto-detect from the email domain.'**
  String get adminServerSmtpHostDescription;

  /// No description provided for @adminServerFieldSmtpPort.
  ///
  /// In en, this message translates to:
  /// **'SMTP Port'**
  String get adminServerFieldSmtpPort;

  /// No description provided for @adminServerFieldSmtpUseSsl.
  ///
  /// In en, this message translates to:
  /// **'Use Direct SSL'**
  String get adminServerFieldSmtpUseSsl;

  /// No description provided for @adminServerSmtpUseSslDescription.
  ///
  /// In en, this message translates to:
  /// **'On = direct SSL (default 465), off = STARTTLS (default 587).'**
  String get adminServerSmtpUseSslDescription;

  /// No description provided for @adminServerFieldEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Email Password or App Password'**
  String get adminServerFieldEmailPassword;

  /// No description provided for @adminServerSectionReverseProxy.
  ///
  /// In en, this message translates to:
  /// **'Reverse Proxy'**
  String get adminServerSectionReverseProxy;

  /// No description provided for @adminServerReverseProxyDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable when the server runs behind a reverse proxy (e.g. Nginx) so client IPs and HTTPS are detected correctly.'**
  String get adminServerReverseProxyDescription;

  /// No description provided for @adminServerFieldReverseProxy.
  ///
  /// In en, this message translates to:
  /// **'Enable Reverse Proxy'**
  String get adminServerFieldReverseProxy;

  /// No description provided for @adminServerFieldProxyCount.
  ///
  /// In en, this message translates to:
  /// **'Trusted Proxy Count'**
  String get adminServerFieldProxyCount;

  /// No description provided for @adminServerEmailPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enabling email verification requires a verification email and an email password.'**
  String get adminServerEmailPasswordRequired;

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

  /// No description provided for @accountLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock Now'**
  String get accountLockNow;

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

  /// No description provided for @chatBackToBottom.
  ///
  /// In en, this message translates to:
  /// **'Back to bottom'**
  String get chatBackToBottom;

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

  /// No description provided for @messageActionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get messageActionPin;

  /// No description provided for @messageActionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get messageActionUnpin;

  /// No description provided for @pinnedMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinnedMessageLabel;

  /// No description provided for @pinnedMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned Messages'**
  String get pinnedMessagesTitle;

  /// No description provided for @noPinnedMessages.
  ///
  /// In en, this message translates to:
  /// **'No pinned messages'**
  String get noPinnedMessages;

  /// No description provided for @viewAllPinned.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAllPinned;

  /// No description provided for @pinnedMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pinned message} other{{count} pinned messages}}'**
  String pinnedMessageCount(num count);

  /// No description provided for @essenceLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 essence} other{{count} essences}}'**
  String essenceLabel(num count);

  /// No description provided for @essenceName.
  ///
  /// In en, this message translates to:
  /// **'Essence'**
  String get essenceName;

  /// No description provided for @essenceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to essence'**
  String get essenceAdd;

  /// No description provided for @essenceRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from essence'**
  String get essenceRemove;

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
  /// **'Font License'**
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

  /// No description provided for @forumPostDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Post'**
  String get forumPostDelete;

  /// No description provided for @forumPostDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Delete this post? Its comments will also be deleted.'**
  String get forumPostDeleteHint;

  /// No description provided for @forumPostDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get forumPostDeleteSuccess;

  /// No description provided for @forumPostDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete post'**
  String get forumPostDeleteFailed;

  /// No description provided for @forumCommentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Comment'**
  String get forumCommentDelete;

  /// No description provided for @forumCommentDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Delete this comment?'**
  String get forumCommentDeleteHint;

  /// No description provided for @forumCommentDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted'**
  String get forumCommentDeleteSuccess;

  /// No description provided for @forumCommentDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete comment'**
  String get forumCommentDeleteFailed;

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

  /// No description provided for @announcementEditHint.
  ///
  /// In en, this message translates to:
  /// **'Edit announcement content...'**
  String get announcementEditHint;

  /// No description provided for @announcementEditSuccess.
  ///
  /// In en, this message translates to:
  /// **'Announcement updated'**
  String get announcementEditSuccess;

  /// No description provided for @announcementEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update announcement'**
  String get announcementEditFailed;

  /// No description provided for @announcementEditEmpty.
  ///
  /// In en, this message translates to:
  /// **'Content cannot be empty'**
  String get announcementEditEmpty;

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

  /// No description provided for @adminAccountSearch.
  ///
  /// In en, this message translates to:
  /// **'Search username, email, or UID'**
  String get adminAccountSearch;

  /// No description provided for @adminAccountCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get adminAccountCreate;

  /// No description provided for @adminAccountCreateDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a server account as an administrator'**
  String get adminAccountCreateDescription;

  /// No description provided for @adminAccountUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get adminAccountUsername;

  /// No description provided for @adminAccountPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get adminAccountPassword;

  /// No description provided for @adminAccountConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get adminAccountConfirmPassword;

  /// No description provided for @adminAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get adminAccountEmail;

  /// No description provided for @adminAccountRole.
  ///
  /// In en, this message translates to:
  /// **'Account role'**
  String get adminAccountRole;

  /// No description provided for @adminAccountSign.
  ///
  /// In en, this message translates to:
  /// **'Profile signature (optional)'**
  String get adminAccountSign;

  /// No description provided for @adminAccountIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Introduction (optional)'**
  String get adminAccountIntroduction;

  /// No description provided for @adminAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get adminAccountRequired;

  /// No description provided for @adminAccountPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get adminAccountPasswordMismatch;

  /// No description provided for @adminAccountCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created'**
  String get adminAccountCreateSuccess;

  /// No description provided for @adminAccountCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create account. Check whether the username exists and your permissions.'**
  String get adminAccountCreateFailed;

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

  /// No description provided for @chatInputPickServerFile.
  ///
  /// In en, this message translates to:
  /// **'Pick from Server'**
  String get chatInputPickServerFile;

  /// No description provided for @chatSyncHistory.
  ///
  /// In en, this message translates to:
  /// **'Syncing chat history...'**
  String get chatSyncHistory;

  /// No description provided for @chatSyncHistoryProgress.
  ///
  /// In en, this message translates to:
  /// **'Syncing history: {count} messages in round {round}'**
  String chatSyncHistoryProgress(int count, int round);

  /// No description provided for @chatSyncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete: {count} messages'**
  String chatSyncComplete(int count);

  /// No description provided for @serverFilePickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search files...'**
  String get serverFilePickerSearch;

  /// No description provided for @serverFilePickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No uploaded files yet'**
  String get serverFilePickerEmpty;

  /// No description provided for @serverFilePickerNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching files'**
  String get serverFilePickerNoMatch;

  /// No description provided for @serverFilePickerError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load files'**
  String get serverFilePickerError;

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

  /// No description provided for @groupFeaturesSection.
  ///
  /// In en, this message translates to:
  /// **'Group Features'**
  String get groupFeaturesSection;

  /// No description provided for @groupEssenceFeature.
  ///
  /// In en, this message translates to:
  /// **'Essence Messages'**
  String get groupEssenceFeature;

  /// No description provided for @groupEssenceFeatureDesc.
  ///
  /// In en, this message translates to:
  /// **'Allow admins to mark essence messages'**
  String get groupEssenceFeatureDesc;

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

  /// No description provided for @settingsCategoryConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsCategoryConnection;

  /// No description provided for @settingsCategoryStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsCategoryStorage;

  /// No description provided for @settingsNotifyWithHaptic.
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback on Notification'**
  String get settingsNotifyWithHaptic;

  /// No description provided for @settingsNotifyWithHapticDescription.
  ///
  /// In en, this message translates to:
  /// **'Trigger haptic feedback when a new in-app notification arrives'**
  String get settingsNotifyWithHapticDescription;

  /// No description provided for @settingsLockscreenReplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Reply on Lock Screen'**
  String get settingsLockscreenReplyTitle;

  /// No description provided for @settingsLockscreenReplyDesc.
  ///
  /// In en, this message translates to:
  /// **'Reply to messages directly from the notification while the device is locked. Message content will be visible on the lock screen'**
  String get settingsLockscreenReplyDesc;

  /// No description provided for @settingsMediaProxy.
  ///
  /// In en, this message translates to:
  /// **'Media Proxy'**
  String get settingsMediaProxy;

  /// No description provided for @settingsMediaProxyDescription.
  ///
  /// In en, this message translates to:
  /// **'Runs a local HTTP proxy to cache and stream media files for smoother playback'**
  String get settingsMediaProxyDescription;

  /// No description provided for @settingsMediaProxyUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not supported on this platform'**
  String get settingsMediaProxyUnsupported;

  /// No description provided for @settingsForceExplicitSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Force explicit sync on chat entry'**
  String get settingsForceExplicitSyncTitle;

  /// No description provided for @settingsForceExplicitSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Always fetch updates with the sync indicator when opening a chat (original behavior)'**
  String get settingsForceExplicitSyncDesc;

  /// No description provided for @settingsExplicitSyncCooldownTitle.
  ///
  /// In en, this message translates to:
  /// **'Explicit sync interval'**
  String get settingsExplicitSyncCooldownTitle;

  /// No description provided for @settingsExplicitSyncCooldownDesc.
  ///
  /// In en, this message translates to:
  /// **'Time since the last entry-triggered sync before opening a chat shows the sync indicator again'**
  String get settingsExplicitSyncCooldownDesc;

  /// No description provided for @settingsSeconds10.
  ///
  /// In en, this message translates to:
  /// **'10 seconds'**
  String get settingsSeconds10;

  /// No description provided for @settingsSeconds30.
  ///
  /// In en, this message translates to:
  /// **'30 seconds'**
  String get settingsSeconds30;

  /// No description provided for @settingsSeconds60.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get settingsSeconds60;

  /// No description provided for @settingsSeconds120.
  ///
  /// In en, this message translates to:
  /// **'2 minutes'**
  String get settingsSeconds120;

  /// No description provided for @settingsSeconds300.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get settingsSeconds300;

  /// No description provided for @settingsStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'Storage used'**
  String get settingsStorageUsed;

  /// No description provided for @settingsStorageFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get settingsStorageFree;

  /// No description provided for @settingsStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Disk info is not available on this platform'**
  String get settingsStorageUnavailable;

  /// No description provided for @settingsChatStorage.
  ///
  /// In en, this message translates to:
  /// **'Chat Message Storage'**
  String get settingsChatStorage;

  /// No description provided for @settingsChatStorageDescription.
  ///
  /// In en, this message translates to:
  /// **'View and manage locally stored chat messages'**
  String get settingsChatStorageDescription;

  /// No description provided for @settingsCloudFiles.
  ///
  /// In en, this message translates to:
  /// **'Cloud Files'**
  String get settingsCloudFiles;

  /// No description provided for @settingsCloudFilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage files uploaded to the server'**
  String get settingsCloudFilesDescription;

  /// No description provided for @settingsAppCache.
  ///
  /// In en, this message translates to:
  /// **'App Cache'**
  String get settingsAppCache;

  /// No description provided for @settingsMediaCache.
  ///
  /// In en, this message translates to:
  /// **'Media Proxy Cache'**
  String get settingsMediaCache;

  /// No description provided for @settingsFlutterCache.
  ///
  /// In en, this message translates to:
  /// **'Flutter Cache'**
  String get settingsFlutterCache;

  /// No description provided for @settingsClearAllCache.
  ///
  /// In en, this message translates to:
  /// **'Clear all caches'**
  String get settingsClearAllCache;

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClearCache;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get settingsCacheCleared;

  /// No description provided for @settingsEnableAnimationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get settingsEnableAnimationsTitle;

  /// No description provided for @settingsEnableAnimationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable page and interface animations'**
  String get settingsEnableAnimationsDesc;

  /// No description provided for @settingsLayoutModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Layout Mode'**
  String get settingsLayoutModeTitle;

  /// No description provided for @settingsLayoutModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose between wide or narrow layout'**
  String get settingsLayoutModeDesc;

  /// No description provided for @settingsLayoutModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsLayoutModeAuto;

  /// No description provided for @settingsLayoutModeForceWide.
  ///
  /// In en, this message translates to:
  /// **'Force Wide'**
  String get settingsLayoutModeForceWide;

  /// No description provided for @settingsLayoutModeForceNarrow.
  ///
  /// In en, this message translates to:
  /// **'Force Narrow'**
  String get settingsLayoutModeForceNarrow;

  /// No description provided for @settingsWideThresholdTitle.
  ///
  /// In en, this message translates to:
  /// **'Wide Screen Threshold'**
  String get settingsWideThresholdTitle;

  /// No description provided for @settingsWideThresholdDesc.
  ///
  /// In en, this message translates to:
  /// **'Switch to the wide layout when the window width reaches this value (only in Auto mode)'**
  String get settingsWideThresholdDesc;

  /// No description provided for @settingsWideThresholdValue.
  ///
  /// In en, this message translates to:
  /// **'{px} px'**
  String settingsWideThresholdValue(Object px);

  /// No description provided for @settingsWeakNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Weak network mode'**
  String get settingsWeakNetworkTitle;

  /// No description provided for @settingsWeakNetworkDesc.
  ///
  /// In en, this message translates to:
  /// **'Use periodic synchronization when the connection is unstable'**
  String get settingsWeakNetworkDesc;

  /// No description provided for @settingsDataSavingTitle.
  ///
  /// In en, this message translates to:
  /// **'Data saving mode'**
  String get settingsDataSavingTitle;

  /// No description provided for @settingsDataSavingDesc.
  ///
  /// In en, this message translates to:
  /// **'Load media only after you tap it'**
  String get settingsDataSavingDesc;

  /// No description provided for @settingsIpOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'IP override mode'**
  String get settingsIpOverrideTitle;

  /// No description provided for @settingsIpOverrideDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect to configured IPs while keeping the original host for TLS'**
  String get settingsIpOverrideDesc;

  /// No description provided for @settingsIpOverrideOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsIpOverrideOff;

  /// No description provided for @settingsIpOverrideMixed.
  ///
  /// In en, this message translates to:
  /// **'Selected domains'**
  String get settingsIpOverrideMixed;

  /// No description provided for @settingsIpOverrideComplete.
  ///
  /// In en, this message translates to:
  /// **'All connections'**
  String get settingsIpOverrideComplete;

  /// No description provided for @settingsIpOverrideDomainsTitle.
  ///
  /// In en, this message translates to:
  /// **'Override domains'**
  String get settingsIpOverrideDomainsTitle;

  /// No description provided for @settingsIpOverrideDomainsDesc.
  ///
  /// In en, this message translates to:
  /// **'One domain per line'**
  String get settingsIpOverrideDomainsDesc;

  /// No description provided for @settingsIpOverrideEntriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Override IPs'**
  String get settingsIpOverrideEntriesTitle;

  /// No description provided for @settingsIpOverrideEntriesDesc.
  ///
  /// In en, this message translates to:
  /// **'One IP or IP:port per line'**
  String get settingsIpOverrideEntriesDesc;

  /// No description provided for @settingsIpOverrideNoEntry.
  ///
  /// In en, this message translates to:
  /// **'No override IP configured'**
  String get settingsIpOverrideNoEntry;

  /// No description provided for @settingsConnectionStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection status'**
  String get settingsConnectionStatusTitle;

  /// No description provided for @settingsConnectionStatusDesc.
  ///
  /// In en, this message translates to:
  /// **'View connection status and run a self-check'**
  String get settingsConnectionStatusDesc;

  /// No description provided for @settingsConnectivitySelfCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Connectivity self-check'**
  String get settingsConnectivitySelfCheckTitle;

  /// No description provided for @settingsConnectivitySelfCheckDesc.
  ///
  /// In en, this message translates to:
  /// **'Test server and configured IP endpoints'**
  String get settingsConnectivitySelfCheckDesc;

  /// No description provided for @settingsConnectivityFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get settingsConnectivityFailed;

  /// No description provided for @chatSearchAllMessages.
  ///
  /// In en, this message translates to:
  /// **'Search all chats'**
  String get chatSearchAllMessages;

  /// No description provided for @chatExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export chat history'**
  String get chatExportTitle;

  /// No description provided for @chatExportJson.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get chatExportJson;

  /// No description provided for @chatExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get chatExportCsv;

  /// No description provided for @chatExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Chat history exported'**
  String get chatExportSuccess;

  /// No description provided for @chatExportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages to export'**
  String get chatExportEmpty;

  /// No description provided for @settingsResetStatsRooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get settingsResetStatsRooms;

  /// No description provided for @settingsResetStatsMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get settingsResetStatsMessages;

  /// No description provided for @settingsResetStatsSize.
  ///
  /// In en, this message translates to:
  /// **'Database size'**
  String get settingsResetStatsSize;

  /// No description provided for @settingsDatabaseExport.
  ///
  /// In en, this message translates to:
  /// **'Export local database'**
  String get settingsDatabaseExport;

  /// No description provided for @settingsDatabaseImport.
  ///
  /// In en, this message translates to:
  /// **'Import local database'**
  String get settingsDatabaseImport;

  /// No description provided for @settingsDatabaseExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Local database exported'**
  String get settingsDatabaseExportSuccess;

  /// No description provided for @settingsDatabaseImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} messages'**
  String settingsDatabaseImportSuccess(int count);

  /// No description provided for @settingsLocalDatabase.
  ///
  /// In en, this message translates to:
  /// **'Local Database'**
  String get settingsLocalDatabase;

  /// No description provided for @settingsOpenDatabaseFolder.
  ///
  /// In en, this message translates to:
  /// **'Open database folder'**
  String get settingsOpenDatabaseFolder;

  /// No description provided for @settingsLocalDatabaseSize.
  ///
  /// In en, this message translates to:
  /// **'Local message database'**
  String get settingsLocalDatabaseSize;

  /// No description provided for @settingsResetLocalMessages.
  ///
  /// In en, this message translates to:
  /// **'Reset local messages'**
  String get settingsResetLocalMessages;

  /// No description provided for @settingsResetLocalMessagesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all locally cached messages from this client. Server messages are not affected.'**
  String get settingsResetLocalMessagesConfirm;

  /// No description provided for @settingsNoLocalMessages.
  ///
  /// In en, this message translates to:
  /// **'No locally stored messages'**
  String get settingsNoLocalMessages;

  /// No description provided for @settingsLocalMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} messages · {size}'**
  String settingsLocalMessageCount(int count, String size);

  /// No description provided for @maxCachedRooms.
  ///
  /// In en, this message translates to:
  /// **'Cached chat rooms'**
  String get maxCachedRooms;

  /// No description provided for @maxCachedRoomsDesc.
  ///
  /// In en, this message translates to:
  /// **'Maximum chat rooms kept in memory. When exceeded, the least recently used room is evicted'**
  String get maxCachedRoomsDesc;

  /// No description provided for @maxCachedRoomsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} rooms'**
  String maxCachedRoomsCount(Object count);

  /// No description provided for @settingsAutoLoadStickersTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-load stickers'**
  String get settingsAutoLoadStickersTitle;

  /// No description provided for @settingsAutoLoadStickersDesc.
  ///
  /// In en, this message translates to:
  /// **'Download and cache sticker images automatically. When off, tap a sticker to load it.'**
  String get settingsAutoLoadStickersDesc;

  /// No description provided for @settingsClearStickerCache.
  ///
  /// In en, this message translates to:
  /// **'Clear sticker cache'**
  String get settingsClearStickerCache;

  /// No description provided for @settingsClearStickerCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete locally cached sticker images.'**
  String get settingsClearStickerCacheDescription;

  /// No description provided for @settingsClearLocalMessages.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClearLocalMessages;

  /// No description provided for @stickerMarketTitle.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get stickerMarketTitle;

  /// No description provided for @stickerSortByDate.
  ///
  /// In en, this message translates to:
  /// **'Sort by date'**
  String get stickerSortByDate;

  /// No description provided for @stickerSortByUsage.
  ///
  /// In en, this message translates to:
  /// **'Sort by popularity'**
  String get stickerSortByUsage;

  /// No description provided for @stickerMarketTab.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get stickerMarketTab;

  /// No description provided for @stickerOwnedTab.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get stickerOwnedTab;

  /// No description provided for @stickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search sticker packs'**
  String get stickerSearchHint;

  /// No description provided for @stickerRemovePack.
  ///
  /// In en, this message translates to:
  /// **'Remove pack'**
  String get stickerRemovePack;

  /// No description provided for @stickerAddPack.
  ///
  /// In en, this message translates to:
  /// **'Add pack'**
  String get stickerAddPack;

  /// No description provided for @stickerMyPacks.
  ///
  /// In en, this message translates to:
  /// **'My sticker packs'**
  String get stickerMyPacks;

  /// No description provided for @stickerCreatePack.
  ///
  /// In en, this message translates to:
  /// **'Create sticker pack'**
  String get stickerCreatePack;

  /// No description provided for @stickerPackName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get stickerPackName;

  /// No description provided for @stickerPackPrefix.
  ///
  /// In en, this message translates to:
  /// **'Prefix'**
  String get stickerPackPrefix;

  /// No description provided for @stickerPackDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get stickerPackDescription;

  /// No description provided for @stickerPackCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get stickerPackCreate;

  /// No description provided for @stickerAddSticker.
  ///
  /// In en, this message translates to:
  /// **'Add sticker'**
  String get stickerAddSticker;

  /// No description provided for @stickerSlugLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get stickerSlugLabel;

  /// No description provided for @stickerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get stickerAdd;

  /// No description provided for @stickerDeletePack.
  ///
  /// In en, this message translates to:
  /// **'Delete pack'**
  String get stickerDeletePack;

  /// No description provided for @forumSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search forums'**
  String get forumSearchTitle;

  /// No description provided for @forumSearchPostsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search posts'**
  String get forumSearchPostsTitle;

  /// No description provided for @forumSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search forums or posts'**
  String get forumSearchHint;

  /// No description provided for @forumSearchCurrentForumHint.
  ///
  /// In en, this message translates to:
  /// **'Search posts in this forum'**
  String get forumSearchCurrentForumHint;

  /// No description provided for @forumSearchForumsHeader.
  ///
  /// In en, this message translates to:
  /// **'Forums'**
  String get forumSearchForumsHeader;

  /// No description provided for @forumSearchPostsHeader.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get forumSearchPostsHeader;

  /// No description provided for @stickerNoPacks.
  ///
  /// In en, this message translates to:
  /// **'No sticker packs'**
  String get stickerNoPacks;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @groupSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Groups'**
  String get groupSearchTitle;

  /// No description provided for @groupSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Group'**
  String get groupSearchHint;

  /// No description provided for @groupSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search Groups'**
  String get groupSearchTooltip;

  /// No description provided for @groupSearchStartHint.
  ///
  /// In en, this message translates to:
  /// **'Start searching for groups'**
  String get groupSearchStartHint;

  /// No description provided for @groupSearchNotFound.
  ///
  /// In en, this message translates to:
  /// **'No groups found'**
  String get groupSearchNotFound;

  /// No description provided for @groupProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Group Profile'**
  String get groupProfileTitle;

  /// No description provided for @groupProfileIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Group Introduction'**
  String get groupProfileIntroduction;

  /// No description provided for @groupProfileEnterHint.
  ///
  /// In en, this message translates to:
  /// **'Join Hint'**
  String get groupProfileEnterHint;

  /// No description provided for @groupProfileGroupId.
  ///
  /// In en, this message translates to:
  /// **'Group ID'**
  String get groupProfileGroupId;

  /// No description provided for @groupProfileGroupIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Group ID copied'**
  String get groupProfileGroupIdCopied;

  /// No description provided for @groupProfileMembers.
  ///
  /// In en, this message translates to:
  /// **'Members: {count}'**
  String groupProfileMembers(int count);

  /// No description provided for @groupProfileRequireReview.
  ///
  /// In en, this message translates to:
  /// **'Admin approval required'**
  String get groupProfileRequireReview;

  /// No description provided for @groupProfileRequireReviewNo.
  ///
  /// In en, this message translates to:
  /// **'No admin approval required'**
  String get groupProfileRequireReviewNo;

  /// No description provided for @groupProfileJoin.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get groupProfileJoin;

  /// No description provided for @groupProfileJoinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Joined the group'**
  String get groupProfileJoinSuccess;

  /// No description provided for @groupProfileJoinPending.
  ///
  /// In en, this message translates to:
  /// **'Application submitted, pending admin approval'**
  String get groupProfileJoinPending;

  /// No description provided for @groupProfileJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to join the group'**
  String get groupProfileJoinFailed;

  /// No description provided for @groupProfileAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'Already a member'**
  String get groupProfileAlreadyMember;

  /// No description provided for @groupProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Group not found'**
  String get groupProfileNotFound;

  /// No description provided for @groupProfileCreator.
  ///
  /// In en, this message translates to:
  /// **'Group Creator'**
  String get groupProfileCreator;

  /// No description provided for @forwardSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forwardSearchTitle;

  /// No description provided for @forwardSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search users and groups'**
  String get forwardSearchHint;

  /// No description provided for @forwardSearchNotFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get forwardSearchNotFound;

  /// No description provided for @forwardConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward this message?'**
  String get forwardConfirmTitle;

  /// No description provided for @forwardConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Forward this message to {name}?'**
  String forwardConfirmContent(String name);

  /// No description provided for @forwardWhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Where to go after forwarding?'**
  String get forwardWhereTitle;

  /// No description provided for @forwardGoToTarget.
  ///
  /// In en, this message translates to:
  /// **'Go to this chat'**
  String get forwardGoToTarget;

  /// No description provided for @forwardStay.
  ///
  /// In en, this message translates to:
  /// **'Stay in current chat'**
  String get forwardStay;

  /// No description provided for @forwardSending.
  ///
  /// In en, this message translates to:
  /// **'Forwarding...'**
  String get forwardSending;

  /// No description provided for @forwardSuccess.
  ///
  /// In en, this message translates to:
  /// **'Forwarded'**
  String get forwardSuccess;

  /// No description provided for @forwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Forward failed'**
  String get forwardFailed;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Current version: {currentVersion}\nLatest version: {remoteVersion}\nUpdate now?'**
  String updateAvailableMessage(String currentVersion, String remoteVersion);

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get updateDownloading;

  /// No description provided for @updateChangelogTitle.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get updateChangelogTitle;

  /// No description provided for @updateDownloadedTitle.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get updateDownloadedTitle;

  /// No description provided for @updateExtractHint.
  ///
  /// In en, this message translates to:
  /// **'Update downloaded. Please extract the archive manually and replace the app to complete the update.'**
  String get updateExtractHint;

  /// No description provided for @updateDownloadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get updateDownloadFailedTitle;

  /// No description provided for @updateDownloadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Update download failed. Please check your network and try again.'**
  String get updateDownloadFailedMessage;

  /// No description provided for @updateDownloadStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start update download'**
  String get updateDownloadStartTitle;

  /// No description provided for @updateApkSaveHint.
  ///
  /// In en, this message translates to:
  /// **'The APK will be saved to:\n{apkPath}'**
  String updateApkSaveHint(String apkPath);
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
