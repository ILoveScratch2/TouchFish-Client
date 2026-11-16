import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/external_auth_config.dart';
import 'api/tf_api_client.dart';

/// 系统浏览器 PKCE 材料
class ExternalAuthPkce {
  const ExternalAuthPkce({
    required this.verifier,
    required this.challenge,
    required this.state,
  });

  final String verifier;
  final String challenge;
  final String state;

  factory ExternalAuthPkce.generate() {
    final verifier = _randomUrlSafe(48);
    final digest = sha256.convert(utf8.encode(verifier));
    return ExternalAuthPkce(
      verifier: verifier,
      challenge: base64Url.encode(digest.bytes).replaceAll('=', ''),
      state: _randomUrlSafe(24),
    );
  }
}

String _randomUrlSafe(int bytes) {
  final random = Random.secure();
  return base64Url
      .encode(List<int>.generate(bytes, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}


class ExternalAuthService extends ChangeNotifier {
  ExternalAuthService._();

  static final ExternalAuthService instance = ExternalAuthService._();

  ExternalAuthConfig? _config;
  String? _baseUrl;


  String? _authUrl;
  Future<ExternalAuthConfig?>? _inflight;
  List<TfExternalAuthProvider> _providers = const [];

  ExternalAuthConfig? get config => _config;
  List<TfExternalAuthProvider> get providers => _providers;

  bool get isAvailable => _config != null && _config!.methods.isNotEmpty;
  bool get isConfigured => _authUrl != null && _authUrl!.isNotEmpty;

  /// 授权服务器是否支持本机回环投递
  bool get supportsLoopback => _config?.supportsLoopback ?? false;

  String? get authUrl => _authUrl;

  static const _timeout = Duration(seconds: 10);

  /// 读当前所选服务器的外部登录配置
  Future<ExternalAuthConfig?> load({bool force = false}) async {
    final inflight = _inflight;
    if (inflight != null) return inflight;
    final future = _load(force: force);
    _inflight = future;
    try {
      return await future;
    } finally {
      _inflight = null;
    }
  }

  Future<ExternalAuthConfig?> _load({required bool force}) async {
    final serverInfo = await TfApiClient.instance.fetchServerInfo();
    if (serverInfo == null) {
      notifyListeners();
      return _config;
    }
    _providers = serverInfo.externalAuthProviders;
    final url = serverInfo.externalAuthUrl;
    if (url == null || url.isEmpty) {
      _authUrl = null;
      _config = null;
      _baseUrl = null;
      notifyListeners();
      return null;
    }
    _authUrl = url;
    if (!force && _config != null && _baseUrl == url) {
      return _config;
    }

    try {
      final response = await http
          .get(Uri.parse('${url.replaceAll(RegExp(r"/+$"), "")}/.well-known/auth-config'))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        _config = null;
        _baseUrl = null;
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        _config = null;
        return null;
      }
      _config = ExternalAuthConfig.tryParse(Map<String, dynamic>.from(decoded));
      _baseUrl = url;
      return _config;
    } catch (_) {
      _config = null;
      _baseUrl = null;
      return null;
    } finally {
      notifyListeners();
    }
  }

  /// 构造授权入口
  Uri? buildAuthorizeUri({
    required String state,
    String clientId = 'touchfish',
    String? target,
    String? redirectUri,
    String? codeChallenge,
  }) {
    final config = _config;
    if (config == null) return null;
    final uri = Uri.tryParse(config.authorizationEndpoint);
    if (uri == null) return null;
    final loopback = redirectUri != null && redirectUri.isNotEmpty;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'client_id': clientId,
      'state': state,
      'response_mode': loopback ? 'loopback' : 'bridge',
      if (target != null && target.isNotEmpty) 'target': target,
      if (loopback) 'redirect': redirectUri,
      if (loopback && codeChallenge != null) 'code_challenge': codeChallenge,
      if (loopback && codeChallenge != null) 'code_challenge_method': 'S256',
    });
  }

  /// 构造第三方登录的入口地址
  Uri? buildProviderStartUri({
    required String providerId,
    required String state,
    String clientId = 'touchfish',
    String? target,
    String? redirectUri,
    String? codeChallenge,
  }) {
    final config = _config;
    final base = _baseUrl;
    if (config == null || base == null) return null;

    final authorize = buildAuthorizeUri(
      state: state,
      clientId: clientId,
      target: target,
      redirectUri: redirectUri,
      codeChallenge: codeChallenge,
    );
    if (authorize == null) return null;
    final relative = authorize.hasQuery
        ? '${authorize.path}?${authorize.query}'
        : authorize.path;

    final declared = config.methodById(providerId)?.startUrl;
    final start = Uri.tryParse(
      declared ?? '${base.replaceAll(RegExp(r"/+$"), "")}/api/auth/oauth/$providerId/start',
    );
    if (start == null) return null;
    return start.replace(
      queryParameters: {...start.queryParameters, 'redirect': relative},
    );
  }

  /// provider 允许在 WebView 里停留的域名
  List<String> allowedHostsFor(String providerId) {
    final method = _config?.methodById(providerId);
    return method?.allowedHosts ?? const [];
  }

  /// 一次性 ticket 换 external_token。
  ///
  /// [codeVerifier] 仅 loopback
  Future<String?> exchangeTicket(
    String ticket, {
    String clientId = 'touchfish',
    String? codeVerifier,
  }) async {
    final config = _config;
    if (config == null) return null;
    try {
      final response = await http
          .post(
            Uri.parse(config.ticketEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'ticket': ticket,
              'client_id': clientId,
              'code_verifier': ?codeVerifier,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final token = decoded['external_token'];
      return token is String && token.isNotEmpty ? token : null;
    } catch (_) {
      return null;
    }
  }

  void clear() {
    _config = null;
    _baseUrl = null;
    _authUrl = null;
    _providers = const [];
    notifyListeners();
  }
}
