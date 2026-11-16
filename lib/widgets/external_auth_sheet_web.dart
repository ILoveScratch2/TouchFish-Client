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
/// 浏览器里没有 InAppWebView 的 JS 桥，也没有深链接收
class ExternalAuthSheet {
  static Future<ExternalAuthResult?> show(
    BuildContext context,
    Uri uri, {
    String title = 'TouchFish Auth',
    List<String> allowedHosts = const [],
    bool allowManualEntry = false,
  }) async {
    // title / allowedHosts 只对 native 的 WebView 有意义：
    // Web 端是整页跳转，无所谓白名单。
    // allowManualEntry 同理：Web 端整页跳转到新标签页，票据需要用户自己复制。
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
