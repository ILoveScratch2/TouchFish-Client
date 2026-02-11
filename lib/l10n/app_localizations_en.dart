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
  String get navChat => 'Chat';

  @override
  String get navAnnouncement => 'Announce';

  @override
  String get navForum => 'Forum';

  @override
  String get navAccount => 'Account';

  @override
  String get chatTabMessages => 'Messages';

  @override
  String get chatTabContacts => 'Contacts';

  @override
  String get chatInvites => 'Invites';

  @override
  String get chatNoInvites => 'No invites';

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
  String get aboutServerRepository => 'Backend Server Repository';

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
      'TouchFish Client is Copyleft free software: you can use, study, share and improve it at any time. You can redistribute or modify it under the GNU Affero General Public License (AGPLv3) published by the Free Software Foundation.';

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
}
