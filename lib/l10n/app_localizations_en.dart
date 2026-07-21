// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'TouchFish';

  @override
  String get appSubtitle => 'Modern instant messaging';

  @override
  String get welcomeStart => 'Get Started';

  @override
  String get welcomeFeatureLightweightTitle => 'Lightweight';

  @override
  String get welcomeFeatureLightweightDesc =>
      'Efficient and resource-friendly design';

  @override
  String get welcomeFeatureMultiplatformTitle => 'Multi-platform';

  @override
  String get welcomeFeatureMultiplatformDesc =>
      'Support Windows, macOS, Linux, Android and Web';

  @override
  String get welcomeFeatureLanTitle => 'No Internet';

  @override
  String get welcomeFeatureLanDesc =>
      'No Internet connection needed, works seamlessly on LAN';

  @override
  String get loginUsername => 'Username';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginLogin => 'Login';

  @override
  String get loginRegister => 'Register';

  @override
  String get loginMsgLoginNotImpl => 'Login function not implemented yet';

  @override
  String get loginMsgRegisterNotImpl => 'Register function not implemented yet';

  @override
  String get registerTitle => 'Register';

  @override
  String get registerCreateAccount => 'Create New Account';

  @override
  String get registerAccountInfo => 'Set up your account';

  @override
  String get registerEmailInfo => 'Enter your email';

  @override
  String get registerVerifyInfo => 'Enter verification code';

  @override
  String get registerUsername => 'Username';

  @override
  String get registerPassword => 'Password';

  @override
  String get registerConfirmPassword => 'Confirm Password';

  @override
  String get registerEmail => 'Email';

  @override
  String get registerVerificationCode => 'Verification Code (6 digits)';

  @override
  String get registerNextStep => 'Next';

  @override
  String get registerPreviousStep => 'Previous';

  @override
  String get registerComplete => 'Complete Registration';

  @override
  String get registerHaveAccount => 'Already have an account? Back to login';

  @override
  String get registerSuccess => 'Registration Successful!';

  @override
  String get registerSuccessMessage =>
      'Your account has been created successfully';

  @override
  String get registerBackToLogin => 'Back to Login';

  @override
  String get registerErrorUsernameRequired => 'Please enter username';

  @override
  String get registerErrorUsernameMinLength =>
      'Username must be at least 3 characters';

  @override
  String get registerErrorPasswordRequired => 'Please enter password';

  @override
  String get registerErrorConfirmPasswordRequired =>
      'Please enter password again';

  @override
  String get registerErrorPasswordMismatch => 'Passwords do not match';

  @override
  String get registerErrorVerificationCodeRequired =>
      'Please enter verification code';

  @override
  String get registerErrorVerificationCodeInvalid =>
      'Verification code must be 6 digits';

  @override
  String get loginErrorEmptyFields => 'Please enter username and password';

  @override
  String get loginErrorUserNotFound => 'User not found';

  @override
  String get loginErrorInvalidCredentials => 'Incorrect password';

  @override
  String get loginErrorNetwork => 'Network error, please try again';

  @override
  String get savedSessionRestoreConnectingTitle => 'Connecting';

  @override
  String get savedSessionRestoreConnectingMessage =>
      'Restoring your saved session and verifying your login. Please wait.';

  @override
  String get savedSessionRestoreFailedTitle => 'Unable to use saved session';

  @override
  String get savedSessionRestoreFailedMessage =>
      'This session can\'t be used on the server. Check your network connection or login credentials.';

  @override
  String get registerErrorCaptchaRequired => 'Please enter the captcha';

  @override
  String get registerCaptchaLoad => 'Loading captcha...';

  @override
  String get registerCaptchaCode => 'Captcha';

  @override
  String get registerCaptchaRefresh => 'Refresh';

  @override
  String get registerErrorFailed => 'Registration failed, please try again';

  @override
  String get registerConfirmInfo => 'Confirm your registration details';

  @override
  String get registerActivateFailed =>
      'Activation failed, please check the code';

  @override
  String get forumLoadFailed => 'Failed to load forums';

  @override
  String get forumPostLoadFailed => 'Failed to load posts';

  @override
  String get forumCommentFailed => 'Failed to post comment';

  @override
  String get forumPostFailed => 'Failed to publish post';

  @override
  String get userProfileNotFound => 'User not found';

  @override
  String get retry => 'Retry';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get settingsEmpty => 'No settings';

  @override
  String get settingsCategoryAppearance => 'Appearance';

  @override
  String get settingsCategoryNotifications => 'Notifications';

  @override
  String get settingsCategoryAbout => 'About';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageDesc => 'Language of the application';

  @override
  String get settingsLanguageSystem => 'System Default';

  @override
  String get settingsLanguageZh => '简体中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLanguageCc => '文言（華夏）';

  @override
  String get settingsThemeTitle => 'Theme';

  @override
  String get settingsThemeDesc => 'Appearance theme of the application';

  @override
  String get settingsThemeSystem => 'System Default';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeColorTitle => 'Theme Color';

  @override
  String get settingsThemeColorDesc => 'Primary color used in the application';

  @override
  String get settingsColorDefault => 'Default';

  @override
  String get settingsColorRed => 'Red';

  @override
  String get settingsColorGreen => 'Green';

  @override
  String get settingsColorPurple => 'Purple';

  @override
  String get settingsColorOrange => 'Orange';

  @override
  String get settingsColorCustom => 'Custom';

  @override
  String get settingsCardOpacityTitle => 'Card Opacity';

  @override
  String get settingsCardOpacityDesc =>
      'Adjust the opacity of card backgrounds';

  @override
  String get settingsWindowOpacityTitle => 'Window Transparency';

  @override
  String get settingsWindowOpacityDesc =>
      'Adjust the transparency of the application window (desktop only)';

  @override
  String get settingsBackgroundImageTitle => 'Background Image';

  @override
  String get settingsBackgroundImageDesc =>
      'Select the application background image';

  @override
  String get settingsBackgroundImageSelect => 'Select Background Image';

  @override
  String get settingsBackgroundImageClear => 'Clear Background Image';

  @override
  String get settingsBackgroundImageGenColor =>
      'Generate Theme from Background';

  @override
  String get settingsBackgroundImageGenColorDesc =>
      'Extract dominant color from background as theme color';

  @override
  String get settingsBackgroundImageSelectSuccess =>
      'Background image selected';

  @override
  String get settingsBackgroundImageClearSuccess => 'Background image cleared';

  @override
  String get settingsBackgroundImageGenColorSuccess =>
      'Theme colors extracted from background';

  @override
  String settingsBackgroundImageGenColorError(String error) {
    return 'Failed to extract colors: $error';
  }

  @override
  String get settingsCustomThemeTitle => 'Custom Theme Colors';

  @override
  String get settingsCustomThemeDesc =>
      'Customize various theme colors of the application';

  @override
  String get settingsCustomThemeSeedColor => 'Seed Color';

  @override
  String get settingsCustomThemePrimary => 'Primary Color';

  @override
  String get settingsCustomThemeSecondary => 'Secondary Color';

  @override
  String get settingsCustomThemeTertiary => 'Tertiary Color';

  @override
  String get settingsCustomThemeSurface => 'Surface Color';

  @override
  String get settingsCustomThemeBackground => 'Background Color';

  @override
  String get settingsCustomThemeError => 'Error Color';

  @override
  String get settingsCustomThemeReset => 'Reset Custom Colors';

  @override
  String get settingsCustomThemeResetConfirm =>
      'Are you sure you want to reset all custom colors?';

  @override
  String get settingsFontFamilyTitle => 'Font';

  @override
  String get settingsFontFamilyDesc => 'Application font family';

  @override
  String get settingsFontHarmonyOS =>
      'HarmonyOS Sans SC (Default, Recommended)';

  @override
  String get settingsFontSystem => 'System Default';

  @override
  String get settingsFontCustomOption => 'Custom';

  @override
  String get settingsCustomFontTitle => 'Custom font';

  @override
  String get settingsCustomFontDesc =>
      'Enter the name of the system font to use';

  @override
  String get settingsCustomFontHint => 'e.g. LXGW WenKai Screen';

  @override
  String get settingsSendModeTitle => 'Send Mode';

  @override
  String get settingsSendModeDesc => 'Keyboard shortcut for sending messages';

  @override
  String get settingsSendModeEnter => 'Press Enter to send';

  @override
  String get settingsSendModeCtrlEnter => 'Press Ctrl+Enter to send';

  @override
  String get settingsEnableMarkdownTitle => 'Render Markdown/LaTeX';

  @override
  String get settingsEnableMarkdownDesc =>
      'Render Markdown and LaTeX formatted text';

  @override
  String get settingsSystemNotificationsTitle => 'System Notifications';

  @override
  String get settingsSystemNotificationsDesc =>
      'Use system notifications for messages';

  @override
  String get settingsInAppNotificationsTitle => 'In-App Notifications';

  @override
  String get settingsInAppNotificationsDesc =>
      'Show notifications within the application';

  @override
  String get settingsNotificationSoundTitle => 'Notification Sound';

  @override
  String get settingsNotificationSoundDesc =>
      'Play sound for in-app notifications';

  @override
  String get settingsChatNotificationsTitle => 'Chat Notifications';

  @override
  String get settingsChatNotificationsDesc =>
      'Configure notification settings for private and group chats';

  @override
  String get settingsPrivateChatTitle => 'Private Chat Notifications';

  @override
  String get settingsGroupChatTitle => 'Group Chat Notifications';

  @override
  String get settingsAboutAppTitle => 'About Application';

  @override
  String get serverTitle => 'Server';

  @override
  String get serverAdd => 'Add Server';

  @override
  String get serverEdit => 'Edit Server';

  @override
  String get serverDelete => 'Delete Server';

  @override
  String get serverSelect => 'Select Server';

  @override
  String get serverUrlLabel => 'Server URL';

  @override
  String get serverUrlHint => 'e.g., touchfish.xin';

  @override
  String get serverCannotDeleteLast => 'Cannot delete the last server';

  @override
  String get serverInvalidUrl => 'Invalid server URL';

  @override
  String get serverAddServer => 'Add';

  @override
  String get serverCancel => 'Cancel';

  @override
  String get serverDisplayName => 'Display Name';

  @override
  String get serverDisplayNameHint => 'e.g., TOUCHFISH Server';

  @override
  String get serverAddress => 'Server Address';

  @override
  String get serverAddressHint => 'e.g., touchfish.xin';

  @override
  String get serverApiPort => 'API Port';

  @override
  String get serverApiPortHint => 'e.g., 8080';

  @override
  String get serverTcpPort => 'TCP Port';

  @override
  String get serverTcpPortHint => 'e.g., 9090';

  @override
  String get serverErrorInvalidAddress => 'Invalid address';

  @override
  String get serverErrorInvalidPort =>
      'Port must be an integer between 0 and 65535';

  @override
  String get serverErrorDuplicatePort => 'Ports cannot be the same';

  @override
  String get serverUseHttps => 'HTTPS';

  @override
  String get serverUseHttpsOn => 'Use encrypted connection';

  @override
  String get serverUseHttpsOff => 'Use unencrypted connection';

  @override
  String get navChat => 'Chat';

  @override
  String get navAnnouncement => 'Announce';

  @override
  String get navForum => 'Forum';

  @override
  String get navAccount => 'Account';

  @override
  String get navAdmin => 'Admin';

  @override
  String get adminTitle => 'Administrator';

  @override
  String get adminDescription => 'Manage TouchFish server';

  @override
  String get adminAccessDenied => 'You do not have administrator access.';

  @override
  String get adminRootOnly =>
      'Only the root account can manage server settings.';

  @override
  String get adminDefaultAssets => 'Default Images';

  @override
  String get adminDefaultAssetsDescription =>
      'Upload the logo and default avatars used by the server.';

  @override
  String get adminDefaultAssetsLoadFailed => 'Failed to load default images';

  @override
  String get adminDefaultAssetChangeAction => 'Upload PNG';

  @override
  String get adminDefaultAssetPngHint =>
      'Only PNG files are accepted by the server.';

  @override
  String get adminDefaultAssetPreviewUnavailable => 'Preview unavailable';

  @override
  String get adminDefaultAssetLogo => 'Server Logo';

  @override
  String get adminDefaultAssetLogoDescription =>
      'Shown in the app header and server branding surfaces.';

  @override
  String get adminDefaultAssetForum => 'Default Forum Image';

  @override
  String get adminDefaultAssetForumDescription =>
      'Used when a forum has no custom image.';

  @override
  String get adminDefaultAssetUser => 'Default User Avatar';

  @override
  String get adminDefaultAssetUserDescription =>
      'Used when a user has not uploaded an avatar.';

  @override
  String get adminDefaultAssetGroup => 'Default Group Avatar';

  @override
  String get adminDefaultAssetGroupDescription =>
      'Used when a group has no custom avatar.';

  @override
  String adminDefaultAssetUploadSuccess(String assetName) {
    return 'Updated $assetName.';
  }

  @override
  String adminDefaultAssetUploadFailed(String assetName) {
    return 'Failed to update $assetName.';
  }

  @override
  String get adminServerSettings => 'Server Settings';

  @override
  String get adminServerSettingsDescription =>
      'Update the server name, registration captcha, and key limits.';

  @override
  String get adminServerSettingsLoadFailed => 'Failed to load server settings';

  @override
  String get adminServerSettingsSaveSuccess => 'Server settings updated';

  @override
  String get adminServerSettingsSaveFailed =>
      'Failed to update server settings';

  @override
  String get adminServerSettingsInvalidInput =>
      'Please check the server settings form and try again.';

  @override
  String get adminServerSettingsCaptchaDescription =>
      'Require a captcha image during registration.';

  @override
  String get adminServerReadOnlyDescription =>
      'These values are returned by the server and cannot be edited here.';

  @override
  String get adminServerFieldServerName => 'Server Name';

  @override
  String get adminServerFieldCaptcha => 'Registration Captcha';

  @override
  String get adminServerFieldFileLastTime => 'File Retention Time (hours)';

  @override
  String get adminServerFileLastTimeDescription => 'Must be 0 or greater.';

  @override
  String get adminServerFieldGroupsLimit => 'Group Limit';

  @override
  String get adminServerFieldSingleGroupMaxPeople => 'Single Group Max Members';

  @override
  String get adminServerFieldMaxFileSize => 'Max File Size';

  @override
  String get adminServerFieldMaxMessageLength => 'Max Message Length';

  @override
  String get adminServerFieldMaxMessageLengthDescription =>
      'Maximum characters per message (minimum 1).';

  @override
  String get adminServerFieldApiPort => 'API Port';

  @override
  String get adminServerFieldTcpPort => 'TCP Port';

  @override
  String get adminServerFieldEmailActivation => 'Email Activation';

  @override
  String get adminServerFieldVerifyEmail => 'Verification Email';

  @override
  String get adminServerUnlimitedHint => 'Use -1 for unlimited.';

  @override
  String get adminPendingForums => 'Pending Forums';

  @override
  String get adminPendingForumsDescription =>
      'Review and approve newly created forums.';

  @override
  String get adminPendingForumsEmpty => 'No forums are waiting for review.';

  @override
  String get adminPendingForumsLoadFailed => 'Failed to load pending forums';

  @override
  String adminPendingForumQueueId(int queueId) {
    return 'Queue #$queueId';
  }

  @override
  String adminPendingForumCreator(String uid) {
    return 'Creator UID: $uid';
  }

  @override
  String get adminPendingForumNoIntroduction => 'No introduction provided.';

  @override
  String get adminApproveForumAction => 'Approve Forum';

  @override
  String get adminApproveForumConfirmTitle => 'Approve forum';

  @override
  String adminApproveForumConfirmMessage(String forumName) {
    return 'Approve \"$forumName\" and publish it to the forum list?';
  }

  @override
  String adminApproveForumSuccess(String forumName) {
    return 'Approved \"$forumName\".';
  }

  @override
  String get adminApproveForumFailed => 'Failed to approve forum.';

  @override
  String get adminRejectForumAction => 'Reject Forum';

  @override
  String get adminRejectForumConfirmTitle => 'Reject forum';

  @override
  String adminRejectForumConfirmMessage(String forumName) {
    return 'Reject \"$forumName\" and remove it from the review queue?';
  }

  @override
  String adminRejectForumSuccess(String forumName) {
    return 'Rejected \"$forumName\".';
  }

  @override
  String get adminRejectForumFailed => 'Failed to reject forum.';

  @override
  String get account => 'Account';

  @override
  String get accountUnauthorized => 'Not Logged In';

  @override
  String get accountLogin => 'Log in';

  @override
  String get accountCreateAccount => 'Create Account';

  @override
  String get accountCreateAccountDescription => 'Sign up for a new account';

  @override
  String get accountLoginDescription => 'Log in to your account';

  @override
  String get accountNotifications => 'Notifications';

  @override
  String get accountSettings => 'Settings';

  @override
  String get accountEditProfile => 'Edit Profile';

  @override
  String get accountProfile => 'Profile';

  @override
  String get accountAbout => 'About';

  @override
  String get accountDebugOptions => 'Debug Options';

  @override
  String get accountLogout => 'Logout';

  @override
  String get accountLogoutConfirm => 'Are you sure you want to logout?';

  @override
  String get accountDescriptionNone => 'No signature';

  @override
  String get accountSignature => 'Personal Signature';

  @override
  String get accountEditSignature => 'Edit Signature';

  @override
  String get accountCreateSignature => 'Create Signature';

  @override
  String get accountUpdateSignature => 'Update Signature';

  @override
  String get accountSignaturePlaceholder => 'Enter your personal signature...';

  @override
  String get accountAppSettings => 'App Settings';

  @override
  String get accountUpdateYourProfile => 'Update Your Profile';

  @override
  String get profileEditTitle => 'Edit Profile';

  @override
  String get profileEditAvatar => 'Avatar';

  @override
  String get profileEditBasicInfo => 'Basic Information';

  @override
  String get profileEditUsername => 'Username';

  @override
  String get profileEditEmail => 'Email';

  @override
  String get profileEditBio => 'Bio';

  @override
  String get profileEditBioPlaceholder => 'Tell us about yourself...';

  @override
  String get profileEditIntroduction => 'Introduction';

  @override
  String get profileEditIntroductionPlaceholder =>
      'Write something about yourself...';

  @override
  String get profileEditSaveChanges => 'Save Changes';

  @override
  String get profileEditChangeAvatar => 'Change Avatar';

  @override
  String get profileEditRemoveAvatar => 'Remove Avatar';

  @override
  String get profileEditUpdated => 'Profile updated';

  @override
  String get profileEditSaveFailed => 'Failed to save some changes';

  @override
  String get profileEditUsernameCannotChange => 'Username cannot be changed';

  @override
  String get chatTabMessages => 'Messages';

  @override
  String get chatTabContacts => 'Contacts';

  @override
  String get chatInvites => 'Invites';

  @override
  String get chatNoInvites => 'No invites';

  @override
  String get chatInviteAccept => 'Accept';

  @override
  String get chatInviteReject => 'Reject';

  @override
  String get notificationTitle => 'Notifications';

  @override
  String get notificationEmpty => 'No notifications';

  @override
  String get notificationClearAll => 'Clear All';

  @override
  String get notificationTabAnnouncements => 'Announcements';

  @override
  String get notificationTabNotifications => 'Notifications';

  @override
  String get chatPinned => 'Pinned';

  @override
  String get chatDirectMessage => 'Direct';

  @override
  String get chatGroupMessage => 'Group';

  @override
  String get chatOnline => 'Online';

  @override
  String get chatOffline => 'Offline';

  @override
  String get chatAway => 'Away';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatDetailLoading => 'Loading...';

  @override
  String get chatDetailUnknownUser => 'Unknown User';

  @override
  String get chatDetailOther => 'Other';

  @override
  String get chatDetailGroupChat => 'Group Chat';

  @override
  String get chatDetailNoMessages =>
      'No messages yet\nSend a message to start chatting';

  @override
  String get chatInputCollapse => 'Collapse';

  @override
  String get chatInputExpand => 'More';

  @override
  String get chatInputAttachment => 'Attachment';

  @override
  String get chatInputTakePhoto => 'Take Photo';

  @override
  String get chatInputTakeVideo => 'Record Video';

  @override
  String get chatInputUploadFile => 'Upload File';

  @override
  String get chatInputRecordAudio => 'Record Audio';

  @override
  String get chatInputPlaceholder => 'Type a message...';

  @override
  String get chatInputFeatureArea => 'Feature Area';

  @override
  String get chatListExpand => 'Expand';

  @override
  String get chatListCollapse => 'Collapse';

  @override
  String get networkStatusTitle => 'Network Status';

  @override
  String get networkStatusConnected => 'Connected to Internet';

  @override
  String get networkStatusConnectedDesc =>
      'You are connected to the internet and can connect to TouchFish servers on the public network';

  @override
  String get networkStatusDisconnected => 'Disconnected from Internet';

  @override
  String get networkStatusDisconnectedDesc =>
      'You are disconnected from the internet and can only connect to local network servers';

  @override
  String get networkStatusCheckingConnection =>
      'Checking network connection...';

  @override
  String get connectionBannerConnecting => 'Connecting';

  @override
  String get connectionBannerDisconnected => 'Disconnected';

  @override
  String get connectionBannerConnected => 'Connected';

  @override
  String get connectionBannerTapToRetry => 'Tap to retry';

  @override
  String get messageActions => 'Message Actions';

  @override
  String get messageActionReply => 'Reply';

  @override
  String get messageActionForward => 'Forward';

  @override
  String get messageActionDelete => 'Delete';

  @override
  String get chatRoomSettings => 'Chat Settings';

  @override
  String get chatRoomMembers => 'Chat Members';

  @override
  String get chatRoomEdit => 'Edit Chat';

  @override
  String get chatRoomEditName => 'Edit Name';

  @override
  String get chatRoomPin => 'Pin Chat';

  @override
  String get chatRoomPinDescription => 'Pin this chat to the top of the list';

  @override
  String get chatRoomPinned => 'Chat pinned';

  @override
  String get chatRoomUnpinned => 'Chat unpinned';

  @override
  String get chatRoomName => 'Chat Name';

  @override
  String get chatRoomContactName => 'Contact Remark Name';

  @override
  String get chatRoomNameHelp => 'Only editable if you have permission';

  @override
  String get chatRoomAlias => 'Chat Alias';

  @override
  String get chatRoomAliasHelp => 'Custom name visible only to you';

  @override
  String get chatRoomDescription => 'Chat Description';

  @override
  String get chatRoomDescriptionHelp =>
      'Custom description visible only to you';

  @override
  String get chatRoomNoDescription => 'No description yet';

  @override
  String get chatRoomNameUpdated => 'Chat name updated';

  @override
  String get chatRoomUpdated => 'Chat information updated';

  @override
  String get chatNotifyLevel => 'Notification Level';

  @override
  String get chatNotifyLevelAll => 'All Messages';

  @override
  String get chatNotifyLevelAllDescription =>
      'Receive notifications for all messages';

  @override
  String get chatNotifyLevelMention => 'Mentions Only';

  @override
  String get chatNotifyLevelMentionDescription =>
      'Only receive notifications when mentioned';

  @override
  String get chatNotifyLevelNone => 'Mute';

  @override
  String get chatNotifyLevelNoneDescription =>
      'Do not receive any notifications';

  @override
  String get chatSearchMessages => 'Search Messages';

  @override
  String get chatSearchMessagesDescription =>
      'Search for messages in this chat';

  @override
  String get chatSearchMessagesPlaceholder => 'Search message content...';

  @override
  String get chatSearchMessagesHint => 'Enter keywords to search messages';

  @override
  String get chatSearchMessagesNoResults => 'No matching messages found';

  @override
  String get chatLeaveRoom => 'Leave Chat';

  @override
  String get chatLeaveRoomDescription => 'Leave this chat room';

  @override
  String get chatLeaveRoomConfirm =>
      'Are you sure you want to leave this chat?';

  @override
  String get chatRoomLeft => 'Left chat room';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get clear => 'Clear';

  @override
  String get save => 'Save';

  @override
  String get leave => 'Leave';

  @override
  String get mediaPickImage => 'Pick Image';

  @override
  String get mediaPickVideo => 'Pick Video';

  @override
  String get mediaPickAudio => 'Pick Audio';

  @override
  String get mediaPickFile => 'Pick File';

  @override
  String get mediaImageMessage => '[Image]';

  @override
  String get mediaVideoMessage => '[Video]';

  @override
  String get mediaAudioMessage => '[Audio]';

  @override
  String get mediaFileMessage => '[File]';

  @override
  String get mediaUnknown => 'Unknown';

  @override
  String get mediaPlayAudio => 'Play Audio';

  @override
  String get mediaPauseAudio => 'Pause Audio';

  @override
  String get userProfileTitle => 'User Profile';

  @override
  String get userProfileUsername => 'Username';

  @override
  String get userProfileEmail => 'Email';

  @override
  String get userProfileUid => 'User ID';

  @override
  String get userProfileJoinedAt => 'Joined';

  @override
  String get userProfilePermission => 'Permission';

  @override
  String get userProfilePermissionAdmin => 'Admin';

  @override
  String get userProfilePermissionModerator => 'Moderator';

  @override
  String get userProfilePermissionUser => 'User';

  @override
  String get userProfilePersonalSign => 'Personal Sign';

  @override
  String get userProfileIntroduction => 'Introduction';

  @override
  String get userProfileNoPersonalSign => 'No personal sign';

  @override
  String get userProfileNoIntroduction => 'No introduction';

  @override
  String get userProfileCopyUid => 'Copy User ID';

  @override
  String get userProfileUidCopied => 'User ID copied';

  @override
  String get userProfileSendMessage => 'Send Message';

  @override
  String get userProfileLoading => 'Loading profile...';

  @override
  String get userProfileAddFriend => 'Add Friend';

  @override
  String get userProfileUnknownEmail => 'Unknown';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersionInfo(String version, String buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get aboutAppInfoSection => 'Application Information';

  @override
  String get aboutPackageName => 'Package Name';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutBuildNumber => 'Build Number';

  @override
  String get aboutLinksSection => 'Links';

  @override
  String get aboutDocumentation => 'Documentation';

  @override
  String get aboutServerRepository => 'Backend Server';

  @override
  String get aboutFontLicense => 'Font License';

  @override
  String get aboutFontLicenseDialogTitle => 'HarmonyOS Sans SC Font License';

  @override
  String get aboutFontLicenseDescription =>
      'This application uses HarmonyOS Sans SC  & LXGW WenKai fonts, provided by Huawei Device Co., Ltd. under the HarmonyOS Sans Fonts License Agreement and LXGW under the SIL Open Font License 1.1. The use of these fonts is subject to their respective license agreements.';

  @override
  String get aboutFontLicenseFullText => 'Full License Text';

  @override
  String get aboutFontLicenseClose => 'Close';

  @override
  String get aboutOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get aboutDeveloperSection => 'Developer Information';

  @override
  String get aboutContactUs => 'Contact Author';

  @override
  String get aboutSourceCode => 'Source Code';

  @override
  String get aboutLicense => 'License';

  @override
  String get aboutLicenseContent =>
      'This project is licensed under the AGPLv3 License';

  @override
  String get aboutLicenseDialogTitle => 'Software License';

  @override
  String get aboutLicenseDescription =>
      'TouchFish Client is Copyleft free software: you can use, study, share and improve it at any time. You can redistribute or modify it under the GNU Affero General Public License 3.0(AGPLv3) published by the Free Software Foundation.';

  @override
  String get aboutLicenseFullText => 'Full License Text';

  @override
  String get aboutLicenseClose => 'Close';

  @override
  String aboutCopyright(String year) {
    return '© $year ILoveScratch2. All rights reserved.';
  }

  @override
  String get aboutMadeWith => 'By ILoveScratch2 & TouchFish Dev Team';

  @override
  String get aboutCopiedToClipboard => 'Copied to clipboard';

  @override
  String get aboutCopyToClipboard => 'Copy to clipboard';

  @override
  String get aboutEasterEggFound => 'Congratulations! You found an easter egg!';

  @override
  String get aboutEasterEggMessage0 => 'This is a Easter Egg!';

  @override
  String get aboutEasterEggMessage1 =>
      'TouchFish v5, redisigned and reproducted for you!';

  @override
  String get aboutEasterEggMessage2 => 'TouchFish is developed by XSFX!';

  @override
  String get aboutEasterEggMessage3 => 'TouchFish is not for touching fish!';

  @override
  String get aboutEasterEggMessage4 =>
      'TouchFish Client is free/libre and open source!';

  @override
  String get aboutEasterEggMessage5 => '';

  @override
  String get aboutEasterEggMessage6 => '';

  @override
  String get aboutEasterEggMessage7 => 'TouchFish, LAUNCH!';

  @override
  String get aboutEasterEggMessage8 => 'Happy TouchFishing!';

  @override
  String get aboutEasterEggMessage9 =>
      'TouchFish Client supports Windows, macOS, Linux and Android!';

  @override
  String get aboutEasterEggMessage10 =>
      'TouchFish is developed by: XSFX, 035966_L3, Piaoztsdy, JohnChiao75 and many other contributors!';

  @override
  String get aboutEasterEggMessage11 =>
      'Taiwan and its affiliated islands have been an inseparable sacred territory of China since ancient times. Adhering to the one-China principle is fundamental. Any external forces and reactionary elements will ultimately be condemned by history. The reunification of Taiwan is an irreversible and unstoppable historical process. Any attempt to split the country is a serious challenge to the fundamental interests of the Chinese nation and the common will of all Chinese people. We firmly safeguard national sovereignty and territorial integrity, adhere to the one-China principle, and oppose any form of \'Taiwan independence\' separatist plot.';

  @override
  String get aboutEasterEggMessage12 =>
      'TouchFish Client is open source under AGPLv3 license, TouchFish server is open source under MIT license, welcome to Contribute!';

  @override
  String get aboutEasterEggMessage13 =>
      'TouchFish v5 has added new features such as forums, announcements, and multiple chat sessions!';

  @override
  String get aboutEasterEggMessage14 =>
      'The dragon steps on the clouds to send messages, and the steed gallops to bring TouchFish';

  @override
  String get aboutEasterEggMessage15 =>
      'TouchFish\'s official server address is touchfish.xin, welcome to visit!';

  @override
  String get aboutEasterEggMessage16 =>
      'TouchFish delivers messages to every corner!';

  @override
  String get aboutEasterEggMessage17 => 'It\'s time to touch fish!';

  @override
  String get aboutEasterEggMessage18 => 'TouchFish, touch the fish!';

  @override
  String get aboutEasterEggMessage19 => 'YOU ARE SO MAD AT TAPPING??';

  @override
  String get aboutEasterEggLevel => 'Easter Egg Level';

  @override
  String aboutEasterEggProgress(int nextLevel, int remaining) {
    return 'To Lv.$nextLevel: $remaining taps';
  }

  @override
  String get aboutEasterEggCompleted =>
      'Congratulations! You\'ve reached the highest level!';

  @override
  String get aboutEasterEggLevelName0 =>
      'You will never find this level in app!';

  @override
  String get aboutEasterEggLevelName1 => 'TouchFish v1';

  @override
  String get aboutEasterEggLevelName2 => 'TouchFish v3';

  @override
  String get aboutEasterEggLevelName3 => 'TouchFish v4';

  @override
  String get aboutEasterEggLevelName4 => 'TouchFish LTS';

  @override
  String get aboutEasterEggLevelName5 => 'TouchFish Plus';

  @override
  String get aboutEasterEggLevelName6 => 'TouchFish Pro';

  @override
  String get aboutEasterEggLevelName7 => 'TouchFish More';

  @override
  String get aboutEasterEggLevelName8 => 'TouchFish UI Remake';

  @override
  String get aboutEasterEggLevelName9 => 'TouchFish Astra';

  @override
  String get aboutEasterEggLevelName10 => 'TouchFish v5';

  @override
  String get aboutEasterEggLevelName11 => 'TouchFish Client';

  @override
  String get aboutEasterEggLevelName12 => 'TouchFish UI Remake 2';

  @override
  String get aboutEasterEggLevelName13 => 'TouchFish CLI';

  @override
  String get aboutEasterEggLevelName14 => 'Xi Shu Fan Xing';

  @override
  String get aboutEasterEggLevelName15 => 'TouchFisher!';

  @override
  String get aboutEasterEggReset => 'Reset Progress';

  @override
  String get aboutEasterEggResetConfirmTitle => 'Confirm Reset';

  @override
  String get aboutEasterEggResetConfirmMessage =>
      'Are you sure you want to reset all easter egg progress? This will reset your level and tap count.';

  @override
  String get aboutEasterEggResetSuccess => 'Progress reset';

  @override
  String get aboutEasterEggResetCancel => 'Cancel';

  @override
  String get aboutEasterEggResetConfirm => 'Confirm Reset';

  @override
  String get licensesTitle => 'Open Source Licenses';

  @override
  String get licensesSearchHint => 'Search packages...';

  @override
  String licensesPackageCount(int count) {
    return '$count packages';
  }

  @override
  String get licensesNoResults => 'No packages found';

  @override
  String get licensesVersion => 'Version';

  @override
  String get licensesDescription => 'Description';

  @override
  String get licensesLicenseType => 'License Type';

  @override
  String get licensesLinks => 'Links';

  @override
  String get licensesHomepage => 'Homepage';

  @override
  String get licensesRepository => 'Repository';

  @override
  String get licensesLicenseText => 'License Text';

  @override
  String get licensesLicenseCopied => 'License text copied to clipboard';

  @override
  String get markdownCopyCode => 'Copy code';

  @override
  String get markdownCodeCopied => 'Code copied to clipboard';

  @override
  String get markdownSpoilerHidden => 'Hidden';

  @override
  String get settingsCorruptedResetNotice =>
      'Local settings seem corrupted and have been reset.';

  @override
  String get debugLogs => 'Debug Logs';

  @override
  String get debugLogsDescription => 'View application logs';

  @override
  String get debugClearMessageDatabase => 'Clear Message Database';

  @override
  String get debugClearMessageDatabaseDescription =>
      'Delete all locally cached messages from this client.';

  @override
  String get debugClearMessageDatabaseConfirmTitle => 'Clear Message Database?';

  @override
  String get debugClearMessageDatabaseConfirmMessage =>
      'All locally cached messages will be deleted. Server messages are not affected.';

  @override
  String get debugClearMessageDatabaseSuccess => 'Message database cleared.';

  @override
  String get debugCustomInfoDialog => 'Custom Info Dialog';

  @override
  String get debugCustomInfoDialogDescription =>
      'Preview the reusable info dialog with caller-defined actions';

  @override
  String get debugCustomErrorDialog => 'Custom Error Dialog';

  @override
  String get debugCustomErrorDialogDescription =>
      'Preview the reusable error dialog with caller-defined actions';

  @override
  String get debugInfoDialogDemoTitle => 'Server Profile Updated';

  @override
  String get debugInfoDialogDemoMessage =>
      'A refreshed server profile is available. Choose what to do next.';

  @override
  String get debugErrorDialogDemoTitle => 'Message Sync Failed';

  @override
  String get debugErrorDialogDemoMessage =>
      'The current sync task did not finish successfully. You can retry now or open settings to inspect the connection.';

  @override
  String debugDialogSelectedAction(String action) {
    return 'Selected action: $action';
  }

  @override
  String get debugMarkdownTester => 'Markdown Test';

  @override
  String get debugMarkdownTesterDescription =>
      'Type Markdown and preview the rendered result';

  @override
  String get debugMarkdownTesterEditorTitle => 'Markdown Input';

  @override
  String get debugMarkdownTesterHint => 'Enter Markdown here';

  @override
  String get debugMarkdownTesterPreviewTitle => 'Rendered Preview';

  @override
  String get debugMarkdownTesterPreviewDescription =>
      'The preview updates as you edit the Markdown source.';

  @override
  String get debugMarkdownTesterEmptyPreview =>
      'Rendered content will appear here.';

  @override
  String get debugApiTester => 'API Test';

  @override
  String get debugApiTesterDescription =>
      'Send API requests to the server and inspect the responses';

  @override
  String get debugApiTesterEndpoint => 'Endpoint';

  @override
  String get debugApiTesterEndpointHint => 'Example: /auth/login';

  @override
  String get debugApiTesterMethod => 'Request Method';

  @override
  String get debugApiTesterMethodGet => 'GET';

  @override
  String get debugApiTesterMethodPost => 'POST';

  @override
  String get debugApiTesterUseCredentials =>
      'Include current login credentials';

  @override
  String get debugApiTesterUseCredentialsDescription =>
      'Append the current uid and password to the submitted parameters.';

  @override
  String get debugApiTesterNoCredentials =>
      'Current login credentials are unavailable.';

  @override
  String get debugApiTesterEncryptRequest => 'Encrypt request body';

  @override
  String get debugApiTesterEncryptRequestDescription =>
      'When enabled, POST requests use the TouchFish encrypted payload format.';

  @override
  String get debugApiTesterEncryptRequestUnavailableForGet =>
      'GET requests are sent without encryption.';

  @override
  String get debugApiTesterQueryParameters => 'Query Parameters';

  @override
  String get debugApiTesterQueryParametersHint =>
      'Enter a JSON object used as GET query parameters';

  @override
  String get debugApiTesterRequestBody => 'Request Body';

  @override
  String get debugApiTesterRequestBodyHint =>
      'Enter a JSON object used as the POST request body';

  @override
  String get debugApiTesterSendRequest => 'Send Request';

  @override
  String get debugApiTesterResultTitle => 'Result';

  @override
  String get debugApiTesterResultDescription =>
      'Inspect the submitted parameters and the server response.';

  @override
  String get debugApiTesterAwaitingResult =>
      'Send a request to view the submitted parameters and response.';

  @override
  String get debugApiTesterStatus => 'Status';

  @override
  String get debugApiTesterStatusUnavailable => 'Unavailable';

  @override
  String get debugApiTesterRequestUrl => 'Request URL';

  @override
  String get debugApiTesterRequestPayload => 'Request Payload';

  @override
  String get debugApiTesterEncodedBody => 'Encoded Request Body';

  @override
  String get debugApiTesterDecryptedResponse => 'Decrypted Response';

  @override
  String get debugApiTesterRawResponse => 'Raw Response';

  @override
  String get debugApiTesterError => 'Error';

  @override
  String get debugApiTesterInvalidEndpoint => 'Please enter an endpoint.';

  @override
  String get debugApiTesterInvalidBody => 'Request body must be a JSON object.';

  @override
  String get debugApiTesterCredentialsUnavailable =>
      'No current login credentials were found.';

  @override
  String get forumTitle => 'Forum';

  @override
  String get forumNotFound => 'Forum not found';

  @override
  String get forumDescription => 'Description';

  @override
  String get forumJoin => 'Join Forum';

  @override
  String get forumJoinSuccess => 'Successfully joined the forum';

  @override
  String get forumLeave => 'Leave Forum';

  @override
  String get forumLeaveHint =>
      'Are you sure you want to leave this forum? You will lose access to forum content.';

  @override
  String get forumEdit => 'Edit Forum';

  @override
  String get forumDelete => 'Delete Forum';

  @override
  String get forumDeleteHint =>
      'Are you sure to delete this forum? This will also delete all the posts under this forum.';

  @override
  String get forumPinnedPosts => 'Pinned Posts';

  @override
  String get forumNoPosts => 'No posts yet';

  @override
  String get forumPostDetail => 'Post Detail';

  @override
  String get forumPostNotFound => 'Post not found';

  @override
  String get forumReply => 'Reply';

  @override
  String forumReplies(int count) {
    return '$count replies';
  }

  @override
  String forumComments(int count) {
    return '$count comments';
  }

  @override
  String get forumNoComments => 'No comments yet';

  @override
  String get forumCommentPlaceholder => 'Write a comment...';

  @override
  String get forumCommentSuccess => 'Comment posted successfully';

  @override
  String get forumShare => 'Share';

  @override
  String get forumPublish => 'Publish';

  @override
  String get forumComposePost => 'New Post';

  @override
  String get forumComposeReply => 'Reply to Post';

  @override
  String get forumPostTitle => 'Title';

  @override
  String get forumPostTitleRequired => 'Please enter a title';

  @override
  String get forumPostContent => 'Content';

  @override
  String get forumPostContentRequired => 'Please enter content';

  @override
  String get forumPostContentMarkdown => 'Supports Markdown formatting';

  @override
  String get forumPostSuccess => 'Post published successfully';

  @override
  String get forumReplySuccess => 'Reply posted successfully';

  @override
  String forumMembersCount(int count) {
    return '$count members';
  }

  @override
  String get forumInviteMember => 'Invite Member';

  @override
  String get forumRemoveMember => 'Remove Member';

  @override
  String get forumRemoveMemberHint => 'Are you sure to remove this member?';

  @override
  String forumMemberRoleEdit(String name) {
    return 'Edit role of $name';
  }

  @override
  String get forumMemberRole => 'Role';

  @override
  String get forumMemberRoleHint => '0=Member, 50=Admin, 100=Owner';

  @override
  String get forumRoleOwner => 'Owner';

  @override
  String get forumRoleAdmin => 'Admin';

  @override
  String get forumRoleMember => 'Member';

  @override
  String get forumTabJoined => 'Joined';

  @override
  String get forumTabExplore => 'Explore';

  @override
  String get forumNoJoined => 'You haven\'t joined any forums yet';

  @override
  String get forumPostDescription => 'Description (optional)';

  @override
  String get forumComposeAttachImage => 'Attach image';

  @override
  String get forumComposeAttachFile => 'Attach file';

  @override
  String get forumCopyLink => 'Copy Link';

  @override
  String get forumCommentSend => 'Send';

  @override
  String get forumExpandEditor => 'Expand editor';

  @override
  String get forumMdBold => 'Bold';

  @override
  String get forumMdItalic => 'Italic';

  @override
  String get forumMdStrikethrough => 'Strikethrough';

  @override
  String get forumMdHeading => 'Heading';

  @override
  String get forumMdList => 'List';

  @override
  String get forumMdQuote => 'Quote';

  @override
  String get forumMdCode => 'Code';

  @override
  String get forumMdLink => 'Link';

  @override
  String get forumCreateTitle => 'Create Forum';

  @override
  String get forumCreateTitleHint => 'Forum name';

  @override
  String get forumCreateDescriptionHint => 'Description (optional)';

  @override
  String get forumCreateSuccess => 'Forum submitted for review';

  @override
  String get forumCreateFailed => 'Failed to create forum';

  @override
  String get forumPinPost => 'Pin Post';

  @override
  String get forumUnpinPost => 'Unpin Post';

  @override
  String get forumDeleteSuccess => 'Forum deleted successfully';

  @override
  String get forumDeleteFailed => 'Failed to delete forum';

  @override
  String get announcementTitle => 'Announcements';

  @override
  String get announcementNoAnnouncements => 'No announcements yet';

  @override
  String get announcementCreate => 'New Announcement';

  @override
  String get announcementCreateHint => 'Write announcement content...';

  @override
  String get announcementCreateEmpty => 'Content cannot be empty';

  @override
  String get announcementCreateSuccess => 'Announcement created';

  @override
  String get announcementCreateFailed => 'Failed to create announcement';

  @override
  String get announcementDeleteConfirm => 'Delete this announcement?';

  @override
  String get announcementDeleteSuccess => 'Announcement deleted';

  @override
  String get announcementDeleteFailed => 'Failed to delete announcement';

  @override
  String get adminAnnouncements => 'Announcements';

  @override
  String get adminAnnouncementsDescription =>
      'Create and manage system announcements';

  @override
  String get adminAccountManagement => 'Account Management';

  @override
  String get adminAccountManagementDescription =>
      'View and manage user accounts';

  @override
  String get adminAccountLoadFailed => 'Failed to load users';

  @override
  String get adminAccountEmpty => 'No users found';

  @override
  String adminAccountCreated(String date) {
    return 'Created: $date';
  }

  @override
  String get adminAccountChangeRole => 'Change Role';

  @override
  String adminAccountChangeRoleTitle(String name) {
    return 'Change role of $name';
  }

  @override
  String get adminAccountCurrentRole => 'Current role';

  @override
  String get adminAccountRoleRoot => 'Root';

  @override
  String get adminAccountRoleAdmin => 'Admin';

  @override
  String get adminAccountRoleUser => 'User';

  @override
  String get adminAccountRoleBanned => 'Banned';

  @override
  String get adminAccountRoleChangeFailed => 'Failed to change role';

  @override
  String adminAccountRoleChangeSuccess(String name, String role) {
    return '$name: role changed to $role';
  }

  @override
  String get adminAccountBanTitle => 'Ban User';

  @override
  String get adminAccountBanAction => 'Ban';

  @override
  String adminAccountBanConfirm(String name) {
    return 'Ban $name? They will be unable to log in.';
  }

  @override
  String adminAccountBanSuccess(String name) {
    return '$name has been banned';
  }

  @override
  String get adminAccountBanFailed => 'Failed to ban user';

  @override
  String get adminAccountUnbanTitle => 'Unban User';

  @override
  String get adminAccountUnbanAction => 'Unban';

  @override
  String adminAccountUnbanConfirm(String name) {
    return 'Unban $name?';
  }

  @override
  String adminAccountUnbanSuccess(String name) {
    return '$name has been unbanned';
  }

  @override
  String get adminAccountUnbanFailed => 'Failed to unban user';

  @override
  String get adminAccountDeleteTitle => 'Delete User';

  @override
  String get adminAccountDeleteAction => 'Delete';

  @override
  String adminAccountDeleteConfirm(String name) {
    return 'Permanently delete $name? This action cannot be undone.';
  }

  @override
  String adminAccountDeleteSuccess(String name) {
    return '$name has been deleted';
  }

  @override
  String get adminAccountDeleteFailed => 'Failed to delete user';

  @override
  String get adminAccountTotalUsers => 'users';

  @override
  String get storageTitle => 'Storage Management';

  @override
  String get storageUploadFile => 'Upload File';

  @override
  String get storageRefresh => 'Refresh';

  @override
  String get storageNotLoggedIn => 'Not logged in';

  @override
  String get storageNoFiles => 'No files uploaded';

  @override
  String get storageDeleteFile => 'Delete File';

  @override
  String storageDeleteConfirm(String fileName) {
    return 'Delete \"$fileName\"? This action cannot be undone.';
  }

  @override
  String storageDeleted(String fileName) {
    return 'Deleted: $fileName';
  }

  @override
  String get storageDeleteFailed => 'Delete failed';

  @override
  String storageUploaded(String fileName) {
    return 'Uploaded: $fileName';
  }

  @override
  String get storageUploadFailed => 'Upload failed';

  @override
  String get storageUploadError => 'Upload error';

  @override
  String get storageCouldNotReadFile => 'Could not read file';

  @override
  String storageFileTooLarge(int size) {
    return 'File too large, max $size MB';
  }

  @override
  String get storageUsed => 'Used';

  @override
  String get storageUnlimited => 'Unlimited';

  @override
  String get storageRetry => 'Retry';

  @override
  String get adminFileManagement => 'File Management';

  @override
  String get adminFileManagementDescription =>
      'View all uploaded files, filter by user, and force delete files.';

  @override
  String get adminFileFilterUid => 'Filter by User ID...';

  @override
  String get adminFileFilter => 'Filter';

  @override
  String get adminFileFilterClear => 'Clear';

  @override
  String get adminFileForceDelete => 'Force Delete';

  @override
  String get adminFileForceDeleteTitle => 'Force Delete File';

  @override
  String adminFileForceDeleteConfirm(String fileName, String owner) {
    return 'Permanently delete \"$fileName\" (owner: $owner)?\n\nThis removes the file from disk and database regardless of references.';
  }

  @override
  String adminFileForceDeleted(String fileName) {
    return 'Force deleted: $fileName';
  }

  @override
  String get adminFileForceDeleteFailed => 'Force delete failed';

  @override
  String get adminFileNoFiles => 'No files on server';

  @override
  String adminFileNoFilesForUid(String uid) {
    return 'No files found for UID $uid';
  }

  @override
  String get adminFileSummaryFiles => 'Files';

  @override
  String get adminFileSummaryUsers => 'Users';

  @override
  String get adminFileSummaryTotal => 'Total';

  @override
  String get chatFunctionTabFiles => 'Files';

  @override
  String get chatFunctionTabEmoji => 'Emoji';

  @override
  String get chatFunctionTabSpecial => 'Special';

  @override
  String get chatFunctionTabFilesHint => 'Select files to send';

  @override
  String get chatFunctionTabEmojiHint => 'Emoji picker coming soon';

  @override
  String get chatFunctionTabSpecialHint => 'Special messages coming soon';

  @override
  String get chatFunctionPickFile => 'Pick File';

  @override
  String get chatSendFailed => 'Send failed';

  @override
  String get chatCreateGroup => 'Create Group';

  @override
  String get chatAddFriend => 'Add Friend';

  @override
  String get chatAddFriendHint => 'Enter username or UID';

  @override
  String get chatSendFailedBanned =>
      'You have been banned and cannot send messages';

  @override
  String get chatSendFailedRateLimited => 'You are sending messages too fast';

  @override
  String get chatSendFailedNotFriends => 'You are not friends with this user';

  @override
  String get chatSendFailedNotGroupMember =>
      'You are not a member of this group';

  @override
  String get chatSendFailedTooLong => 'Message is too long';

  @override
  String get groupNameLabel => 'Group Name';

  @override
  String get groupIntroLabel => 'Introduction';

  @override
  String get groupEnterHintLabel => 'Join Hint';

  @override
  String get groupCreateNameEmpty => 'Group name cannot be empty';

  @override
  String groupCreateNameLength(int minLen, int maxLen) {
    return 'Group name must be $minLen to $maxLen characters';
  }

  @override
  String get groupCreateFailedLimit =>
      'Creation failed, check group count limit';

  @override
  String get groupSettingsSection => 'Group Settings';

  @override
  String get groupMembersSection => 'Members';

  @override
  String get groupJoinRequestsSection => 'Join Requests';

  @override
  String get groupAllowDirectJoin => 'Allow direct join';

  @override
  String get groupAllowDirectJoinDesc => 'Non-members can request to join';

  @override
  String get groupRequireReview => 'Require review';

  @override
  String get groupRequireReviewDesc => 'Join requests require owner approval';

  @override
  String get groupTransferOwner => 'Transfer Ownership';

  @override
  String get groupTransferOwnerConfirm =>
      'After transfer, you will lose owner permissions. Continue?';

  @override
  String get groupTransferOwnerConfirmAction => 'Confirm Transfer';

  @override
  String get groupInviteMember => 'Invite Member';

  @override
  String get groupInviteMemberHint => 'Enter username or UID of friend';

  @override
  String get groupInvitePendingReview => 'Invitation sent, pending review';

  @override
  String get groupInviteJoined => 'Invited to group';

  @override
  String get groupInviteFailed =>
      'Invitation failed. Make sure the user exists and is your friend';

  @override
  String get groupAvatarPermissionDenied =>
      'Only owner or admin can change group avatar';

  @override
  String get groupAvatarUpdateSuccess => 'Group avatar updated';

  @override
  String get groupAvatarUploadFailedSize => 'Upload failed, check file size';

  @override
  String get groupJoinDirectRequest => 'Direct join request';

  @override
  String groupJoinInvitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String get groupRemoveAdmin => 'Remove Admin';

  @override
  String get groupSetAdmin => 'Set as Admin';

  @override
  String get groupRemoveMemberAction => 'Remove from Group';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonMe => '(me)';

  @override
  String get commonOk => 'OK';

  @override
  String get commonFailedOperation => 'Operation failed, please retry';

  @override
  String get commonUserNotFound => 'User not found';

  @override
  String get commonFileReadError => 'Cannot read file';

  @override
  String get chatLoading => 'Loading...';

  @override
  String get chatInputNotConnected => 'Not connected to chat server';

  @override
  String get chatInviteAcceptFailed => 'Failed to accept friend request';

  @override
  String get chatInviteRejectFailed => 'Failed to reject friend request';

  @override
  String get userProfileFriendRequestHint => 'Say hello...';

  @override
  String userProfileFriendRequestSent(String username) {
    return 'Friend request sent to $username';
  }

  @override
  String get userProfileFriendRequestFailed => 'Failed to send friend request';
}
