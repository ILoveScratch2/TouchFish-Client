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
  const ExternalAuthSheet({super.key, required this.uri});

  final Uri uri;

  static Future<ExternalAuthResult?> show(BuildContext context, Uri uri) {
    return showModalBottomSheet<ExternalAuthResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExternalAuthSheet(uri: uri),
    );
  }

  @override
  State<ExternalAuthSheet> createState() => _ExternalAuthSheetState();
}

class _ExternalAuthSheetState extends State<ExternalAuthSheet> {
  String? _error;
  String? _blockedNavigation;

  void _onWebViewCreated(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'touchfishAuthDone',
      callback: (args) {
        final payload = args.isNotEmpty ? args.first : null;
        if (payload is! Map) return;
        final ticket = payload['ticket'];
        if (ticket is! String || ticket.isEmpty) return;
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
                    'TouchFish Auth',
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
                '已阻止跳转到站外页面：$_blockedNavigation',
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
                    ),
                    // JS 桥是页面级的：任何被导航到的页面都能调 touchfishAuthDone。
                    // 因此只允许停留在授权服务器同源页面，避免用户点到站外链接后
                    // 被一个不属于我们的页面回传攻击者的 ticket。
                    shouldOverrideUrlLoading: (controller, action) async {
                      final target = action.request.url;
                      if (target == null) return NavigationActionPolicy.ALLOW;
                      final allowed = target.host == widget.uri.host &&
                          target.scheme == widget.uri.scheme &&
                          (target.port == widget.uri.port ||
                              (target.port == 0 && widget.uri.port == 0));
                      if (!allowed) {
                        _blockedNavigation = target.toString();
                        if (mounted) setState(() {});
                      }
                      return allowed
                          ? NavigationActionPolicy.ALLOW
                          : NavigationActionPolicy.CANCEL;
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
