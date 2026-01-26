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
  String get settingsTitle => 'Settings';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get settingsEmpty => 'No settings';

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
}
