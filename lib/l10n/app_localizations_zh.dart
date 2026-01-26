// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'TouchFish';

  @override
  String get appSubtitle => '现代化的即时通讯';

  @override
  String get welcomeStart => '开始使用';

  @override
  String get welcomeFeatureLightweightTitle => '轻量级';

  @override
  String get welcomeFeatureLightweightDesc => '高效且节省资源的设计';

  @override
  String get welcomeFeatureMultiplatformTitle => '多平台';

  @override
  String get welcomeFeatureMultiplatformDesc =>
      '支持 Windows、macOS、Linux、Android 和 Web';

  @override
  String get welcomeFeatureLanTitle => '无公网';

  @override
  String get welcomeFeatureLanDesc => '无需 Internet 连接,局域网内畅通无阻';

  @override
  String get loginUsername => '用户名';

  @override
  String get loginPassword => '密码';

  @override
  String get loginLogin => '登录';

  @override
  String get loginRegister => '注册';

  @override
  String get loginMsgLoginNotImpl => '暂时无登录功能实现';

  @override
  String get loginMsgRegisterNotImpl => '暂时无注册功能实现';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsTooltip => '设置';

  @override
  String get settingsEmpty => '设置暂无';

  @override
  String get serverTitle => '服务器';

  @override
  String get serverAdd => '添加服务器';

  @override
  String get serverEdit => '编辑服务器';

  @override
  String get serverDelete => '删除服务器';

  @override
  String get serverSelect => '选择服务器';

  @override
  String get serverUrlLabel => '服务器地址';

  @override
  String get serverUrlHint => '例如：touchfish.xin';

  @override
  String get serverCannotDeleteLast => '不能删除最后一个服务器';

  @override
  String get serverInvalidUrl => '无效的服务器地址';

  @override
  String get serverAddServer => '添加';

  @override
  String get serverCancel => '取消';
}
