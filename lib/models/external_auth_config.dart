/// 外部登录平台（TouchFish Auth）的登录方式清单。
///
/// 由服务端 `/.well-known/auth-config` 下发，客户端只负责渲染，
/// 不硬编码 GitHub/Google 之类的 provider。
class ExternalAuthMethod {
  const ExternalAuthMethod({
    required this.id,
    required this.kind,
    required this.displayName,
    this.enabled = true,
    this.hint,
    this.startUrl,
    this.allowedHosts = const [],
  });

  final String id;

  /// password / tfv5 / oauth2。未知 kind 应跳过，不要崩。
  final String kind;
  final String displayName;
  final bool enabled;
  final String? hint;

  /// 仅 oauth2：发起授权的入口地址
  final String? startUrl;

  /// 仅 oauth2：走完授权需要停留的第三方域名
  final List<String> allowedHosts;

  static ExternalAuthMethod? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    final kind = json['kind'];
    if (id is! String || id.isEmpty || kind is! String || kind.isEmpty) {
      return null;
    }
    final name = json['display_name'];
    final hosts = json['allowed_hosts'];
    return ExternalAuthMethod(
      id: id,
      kind: kind,
      displayName: name is String && name.trim().isNotEmpty ? name.trim() : id,
      enabled: json['enabled'] as bool? ?? true,
      hint: json['hint'] is String ? json['hint'] as String : null,
      startUrl: json['start_url'] is String && (json['start_url'] as String).isNotEmpty
          ? json['start_url'] as String
          : null,
      allowedHosts: hosts is List
          ? hosts
              .whereType<String>()
              .map((value) => value.trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
          : const [],
    );
  }
}

class ExternalAuthConfig {
  const ExternalAuthConfig({
    required this.issuer,
    required this.authorizationEndpoint,
    required this.ticketEndpoint,
    required this.methods,
  });

  final String issuer;
  final String authorizationEndpoint;
  final String ticketEndpoint;
  final List<ExternalAuthMethod> methods;

  static ExternalAuthConfig? tryParse(Map<String, dynamic> json) {
    final issuer = json['issuer'];
    final authorize = json['authorization_endpoint'];
    final ticket = json['ticket_endpoint'];
    if (issuer is! String || authorize is! String || ticket is! String) {
      return null;
    }
    final raw = json['methods'];
    final methods = <ExternalAuthMethod>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final parsed = ExternalAuthMethod.tryParse(
            Map<String, dynamic>.from(item),
          );
          if (parsed != null) methods.add(parsed);
        }
      }
    }
    return ExternalAuthConfig(
      issuer: issuer,
      authorizationEndpoint: authorize,
      ticketEndpoint: ticket,
      methods: methods.where((method) => method.enabled).toList(growable: false),
    );
  }

  /// 除本平台账号密码以外可用的方式。
  List<ExternalAuthMethod> get alternativeMethods => methods
      .where((method) => method.kind != 'password')
      .toList(growable: false);

  /// oauth2
  List<ExternalAuthMethod> get oauthMethods => methods
      .where((method) => method.kind == 'oauth2')
      .toList(growable: false);

  ExternalAuthMethod? methodById(String id) {
    for (final method in methods) {
      if (method.id == id) return method;
    }
    return null;
  }
}
