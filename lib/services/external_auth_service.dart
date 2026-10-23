import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/external_auth_config.dart';
import 'api/tf_api_client.dart';

/// 外部登录平台的能力发现与票据兑换。
///
/// 流程：服务端 /info 下发 external_auth_url
///   → GET {url}/.well-known/auth-config 拿登录方式
///   → WebView 打开 authorization_endpoint
///   → 页面通过 JS 桥回传一次性 ticket
///   → POST {url}/api/auth/ticket 换 external_token
///   → 交给 AuthState 调 /auth/external/login
class ExternalAuthService extends ChangeNotifier {
  ExternalAuthService._();

  static final ExternalAuthService instance = ExternalAuthService._();

  ExternalAuthConfig? _config;
  String? _baseUrl;
  Future<ExternalAuthConfig?>? _inflight;

  ExternalAuthConfig? get config => _config;
  bool get isAvailable => _config != null && _config!.methods.isNotEmpty;

  static const _timeout = Duration(seconds: 10);

  /// 读当前所选服务器的外部登录配置。未启用时返回 null。
  ///
  /// 并发调用共享同一个进行中的请求：首次加载时第二个调用者若走
  /// "已在加载就返回当前配置"，拿到的会是 null，等于假失败。
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
    final url = serverInfo?.externalAuthUrl;
    if (url == null || url.isEmpty) {
      _config = null;
      _baseUrl = null;
      notifyListeners();
      return null;
    }
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

  /// 构造 hosted 授权页地址。state 由调用方生成并校验回传值。
  Uri? buildAuthorizeUri({
    required String state,
    String clientId = 'touchfish',
    String? target,
  }) {
    final config = _config;
    if (config == null) return null;
    final uri = Uri.tryParse(config.authorizationEndpoint);
    if (uri == null) return null;
    // 合并而非覆盖：授权端点自身可能已带 query（版本号、租户等），
    // 直接 replace 会把它清掉。
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'client_id': clientId,
      'state': state,
      'response_mode': 'bridge',
      if (target != null && target.isNotEmpty) 'target': target,
    });
  }

  /// 一次性 ticket 换 external_token。
  Future<String?> exchangeTicket(String ticket, {String clientId = 'touchfish'}) async {
    final config = _config;
    if (config == null) return null;
    try {
      final response = await http
          .post(
            Uri.parse(config.ticketEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ticket': ticket, 'client_id': clientId}),
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
    notifyListeners();
  }
}
