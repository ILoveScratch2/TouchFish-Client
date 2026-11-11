import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// hosted 授权页的回传结果。
class ExternalAuthResult {
  const ExternalAuthResult({required this.ticket, this.state});

  final String ticket;
  final String? state;
}

/// 打开 TouchFish Auth 的授权页，等页面通过 JS 桥回传一次性 ticket。
///
/// 与第三方验证码 Sheet 同一范式（见 third_party_captcha_sheet_native.dart），
/// 因此不需要额外的原生配置或深链接收。
class ExternalAuthSheet extends StatefulWidget {
  const ExternalAuthSheet({
    super.key,
    required this.uri,
    this.title = 'TouchFish Auth',
    this.allowedHosts = const [],
  });

  final Uri uri;

  /// 第三方登录涉及的外部域名（GitHub 等）
  final List<String> allowedHosts;
  final String title;

  static Future<ExternalAuthResult?> show(
    BuildContext context,
    Uri uri, {
    String title = 'TouchFish Auth',
    List<String> allowedHosts = const [],
  }) {
    return showModalBottomSheet<ExternalAuthResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExternalAuthSheet(
        uri: uri,
        title: title,
        allowedHosts: allowedHosts,
      ),
    );
  }

  @override
  State<ExternalAuthSheet> createState() => _ExternalAuthSheetState();
}

class _ExternalAuthSheetState extends State<ExternalAuthSheet> {
  String? _error;
  String? _blockedNavigation;

  /// 授权服务器同源判定
  bool _isAuthOrigin(Uri? target) {
    if (target == null) return false;
    return target.scheme == widget.uri.scheme &&
        target.host == widget.uri.host &&
        (target.port == widget.uri.port ||
            (target.port == 0 && widget.uri.port == 0));
  }

  /// 第三方登录会离开授权服务器，必须放行平台下发的域名
  void _noteNavigation(Uri target) {
    if (_isAuthOrigin(target)) return;
    final host = target.host.toLowerCase();
    for (final allowed in widget.allowedHosts) {
      if (host == allowed || host.endsWith('.$allowed')) return;
    }
    debugPrint('[ExternalAuth] 顶层导航离开授权域名: $target');
  }

  /// 非 Web 协议不可。
  static bool _isWebScheme(Uri target) {
    final scheme = target.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'touchfishAuthDone',
      callback: (args) async {
        final payload = args.isNotEmpty ? args.first : null;
        if (payload is! Map) return;
        final ticket = payload['ticket'];
        if (ticket is! String || ticket.isEmpty) return;
        // 放行 github.com 之后，桥仍必须只接受同源页面的回传
        final current = await controller.getUrl();
        if (!_isAuthOrigin(current)) return;
        if (!mounted) return;
        Navigator.pop(
          context,
          ExternalAuthResult(
            ticket: ticket,
            state: payload['state'] is String ? payload['state'] as String : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_blockedNavigation != null)
            Container(
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '已拦截非 Web 协议跳转：$_blockedNavigation',
                style: theme.textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: theme.colorScheme.error),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                : InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.uri.toString())),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                      // 验证码在 iframe 里要写 cookie
                      // 第三方登录也依赖 provider 的会话 cookie
                      thirdPartyCookiesEnabled: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      supportMultipleWindows: false,
                    ),
                    shouldOverrideUrlLoading: (controller, action) async {
                      final target = action.request.url;
                      if (target == null) return NavigationActionPolicy.ALLOW;

                      final isWeb = _isWebScheme(target);
                      if (!action.isForMainFrame) {
                        return isWeb
                            ? NavigationActionPolicy.ALLOW
                            : NavigationActionPolicy.CANCEL;
                      }

                      if (isWeb) {
                        _noteNavigation(target);
                        if (_blockedNavigation != null && mounted) {
                          setState(() => _blockedNavigation = null);
                        }
                        return NavigationActionPolicy.ALLOW;
                      }

                      if (mounted) {
                        setState(() => _blockedNavigation = target.toString());
                      }
                      return NavigationActionPolicy.CANCEL;
                    },
                    onWebViewCreated: _onWebViewCreated,
                    onReceivedError: (controller, request, error) {
                      if (request.isForMainFrame != true) return;
                      if (!mounted) return;
                      setState(() => _error = error.description);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 便于调试：把 JS 桥的载荷序列化后再打印（不含任何长期凭据）。
String debugBridgePayload(ExternalAuthResult result) =>
    jsonEncode({'state': result.state, 'ticket_length': result.ticket.length});
