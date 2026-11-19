import 'package:flutter/foundation.dart';

import '../models/settings_service.dart';
import '../utils/talker.dart';

/// 连接安全提示横幅关闭
class SecurityNoticeService extends ChangeNotifier {
  SecurityNoticeService._();

  static final SecurityNoticeService instance = SecurityNoticeService._();

  static const String kInsecureContextDismissedKey =
      'securityNoticeInsecureContextDismissedV1';
  static const String kHttpsFallbackDismissedKey =
      'securityNoticeHttpsFallbackDismissedV1';

  bool _initialized = false;
  bool _insecureContextDismissed = false;
  bool _httpsFallbackDismissed = false;
  bool _httpsFallbackActive = false;

  bool get insecureContextDismissed => _insecureContextDismissed;

  bool get httpsFallbackDismissed => _httpsFallbackDismissed;

  /// 已请求 HTTPS 但实际回退到 HTTP
  bool get httpsFallbackActive => _httpsFallbackActive;

  Future<void> init() async {
    if (_initialized) return;
    await SettingsService.instance.init();
    _insecureContextDismissed = SettingsService.instance.getValue<bool>(
      kInsecureContextDismissedKey,
      false,
    );
    _httpsFallbackDismissed = SettingsService.instance.getValue<bool>(
      kHttpsFallbackDismissedKey,
      false,
    );
    _initialized = true;
    notifyListeners();
  }

  Future<void> dismissInsecureContext() async {
    if (_insecureContextDismissed) return;
    _insecureContextDismissed = true;
    notifyListeners();
    await SettingsService.instance.setValue(kInsecureContextDismissedKey, true);
    talker.info('SecurityNotice: insecure context banner dismissed for good');
  }

  Future<void> dismissHttpsFallback() async {
    if (_httpsFallbackDismissed) return;
    _httpsFallbackDismissed = true;
    notifyListeners();
    await SettingsService.instance.setValue(kHttpsFallbackDismissedKey, true);
    talker.info('SecurityNotice: https fallback banner dismissed for good');
  }

  void reportHttpsFallback() {
    if (_httpsFallbackActive) return;
    _httpsFallbackActive = true;
    notifyListeners();
    talker.warning(
      'SecurityNotice: HTTPS was requested but unreachable, fell back to HTTP',
    );
  }

  void clearHttpsFallback() {
    if (!_httpsFallbackActive) return;
    _httpsFallbackActive = false;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _initialized = false;
    _insecureContextDismissed = false;
    _httpsFallbackDismissed = false;
    _httpsFallbackActive = false;
  }
}
