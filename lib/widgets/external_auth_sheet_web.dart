import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// hosted 授权页的回传结果（与 native 版保持同名同结构）。
class ExternalAuthResult {
  const ExternalAuthResult({required this.ticket, this.state});

  final String ticket;
  final String? state;
}

/// Web 端的降级实现。
///
/// 浏览器里没有 InAppWebView 的 JS 桥，也没有深链接收，
/// 因此这里只负责把授权页在新标签页打开，并提示用户改用客户端完成。
/// 需要 Web 端闭环时应改走 `/authorize` 的 redirect_uri + 后端换票，
/// 那是独立的一期工作，不在本次范围内。
class ExternalAuthSheet {
  static Future<ExternalAuthResult?> show(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          launched ? '请在新标签页完成授权，然后在客户端继续' : '无法打开授权页面',
        ),
      ),
    );
    return null;
  }
}
