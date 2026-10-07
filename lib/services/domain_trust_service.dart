import 'package:flutter/foundation.dart';

import '../models/settings_service.dart';
import 'api/tf_api_client.dart';

/// Zero Trust!
class DomainTrustService extends ChangeNotifier {
  DomainTrustService._();

  static final DomainTrustService instance = DomainTrustService._();

  static const String kImageBlockEnabledKey = 'domainTrustImageBlockEnabled';
  static const String kLinkWarningEnabledKey = 'domainTrustLinkWarningEnabled';
  static const String kTrustedDomainsKey = 'trustedDomains';
  static const String kConfirmCountsKey = 'domainTrustConfirmCounts';

  /// 我们相信你 xsfx
  static const List<String> defaultTrustedDomains = [
    'touchfish.xin/*',
    '*.touchfish.xin/*',
    'touchfish.us.ci/*',
    'bopid.cn/*',
    'ilovescratch.us.ci/*',
    '*.ilovescratch.us.ci/*',
    'piaoztsdy.cn/*',
    '*.piaoztsdy.cn/*',
    'icc.gt.tc/*',
    'github.com/*',
    '*.githubusercontent.com/*',
    'luogu.com.cn/*',
    '*.luogu.com.cn/*',
    'luogu.com/*',
    '*.luogu.com/*',
    'luogu.me/*',
    'bilibili.com/*',
    'b23.tv/*',
    'bing.com/*',
    'google.com/*',
  ];

  bool get imageProtectionEnabled =>
      SettingsService.instance.getValue<bool>(kImageBlockEnabledKey, true);

  bool get linkProtectionEnabled =>
      SettingsService.instance.getValue<bool>(kLinkWarningEnabledKey, true);

  List<String> get trustedDomains {
    final raw = SettingsService.instance.getValue<String>(
      kTrustedDomainsKey,
      '',
    );
    if (raw.trim().isEmpty) return List.unmodifiable(defaultTrustedDomains);
    return raw
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> setTrustedDomains(List<String> domains) async {
    final normalized = domains
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('\n');
    await SettingsService.instance.setValue(kTrustedDomainsKey, normalized);
    notifyListeners();
  }

  Future<void> resetTrustedDomains() async {
    await SettingsService.instance.remove(kTrustedDomainsKey);
    notifyListeners();
  }

  Future<void> addTrustedDomain(String host) async {
    final normalized = host.toLowerCase();
    if (await isTrustedHost(normalized)) return;
    await setTrustedDomains([...trustedDomains, '$normalized/*']);
  }

  Map<String, int> _loadConfirmCounts() {
    final json = SettingsService.instance.getJsonValue(kConfirmCountsKey);
    if (json == null) return {};
    return json.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );
  }

  Future<void> _saveConfirmCounts(Map<String, int> counts) async {
    await SettingsService.instance.setJsonValue(
      kConfirmCountsKey,
      counts.map((key, value) => MapEntry(key, value)),
    );
  }

  Future<int> confirmCountFor(String host) async {
    final counts = _loadConfirmCounts();
    return counts[host.toLowerCase()] ?? 0;
  }

  Future<bool> shouldSuggestTrust(String host) async {
    return await confirmCountFor(host) >= 2;
  }

  Future<void> recordConfirmedOpen(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return;
    final counts = _loadConfirmCounts();
    counts[host] = (counts[host] ?? 0) + 1;
    await _saveConfirmCounts(counts);
  }

  String? _serverHost;

  Future<String?> get _currentServerHost async {
    if (_serverHost != null) return _serverHost;
    try {
      final baseUrl = await TfApiClient.instance.getBaseUrl();
      _serverHost = Uri.tryParse(baseUrl)?.host.toLowerCase();
    } catch (_) {
      _serverHost = null;
    }
    return _serverHost;
  }

  Future<void> refreshServerHost() async {
    _serverHost = null;
    await _currentServerHost;
    notifyListeners();
  }

  Future<bool> isTrustedHost(String host) async {
    final normalized = host.toLowerCase();
    if (await _currentServerHost == normalized) return true;
    for (final pattern in trustedDomains) {
      if (matchesHostPattern(normalized, pattern)) return true;
    }
    return false;
  }

  Future<bool> isTrustedUrl(Uri uri) async {
    if (!uri.hasAuthority || uri.host.isEmpty) return true;
    return isTrustedHost(uri.host);
  }

  Future<bool> requiresLinkWarning(Uri uri) async {
    if (!linkProtectionEnabled) return false;
    return !(await isTrustedUrl(uri));
  }

  Future<bool> requiresImageBlock(Uri uri) async {
    if (!imageProtectionEnabled) return false;
    return !(await isTrustedUrl(uri));
  }

  @visibleForTesting
  bool matchesHostPattern(String host, String pattern) {
    var p = pattern.trim();
    if (p.isEmpty) return false;
    final slash = p.indexOf('/');
    if (slash >= 0) p = p.substring(0, slash);
    if (p.isEmpty) return false;
    p = p.toLowerCase();
    if (p.startsWith('*.')) {
      final base = p.substring(2);
      return host == base || host.endsWith('.$base');
    }
    return host == p;
  }
}
