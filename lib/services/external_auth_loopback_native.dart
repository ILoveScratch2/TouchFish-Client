import 'dart:async';
import 'dart:io';

/// 系统浏览器
class ExternalAuthLoopback {
  ExternalAuthLoopback._(this._server, this._port);

  final HttpServer _server;
  final int _port;

  static const callbackPath = '/auth/callback';
  static const _candidatePorts = [53683, 53684, 53685, 53686, 53687];

  String get redirectUri => 'http://127.0.0.1:$_port$callbackPath';

  /// 依次尝试候选端口
  static Future<ExternalAuthLoopback?> start() async {
    for (final candidate in _candidatePorts) {
      try {
        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          candidate,
        );
        return ExternalAuthLoopback._(server, candidate);
      } on SocketException {
        continue;
      }
    }
    return null;
  }
  Future<String?> waitForTicket(
    String state, {
    Duration timeout = const Duration(minutes: 3),
  }) {
    final completer = Completer<String?>();
    final subscription = _server.listen((request) async {
      final params = request.uri.queryParameters;
      if (request.uri.path != callbackPath) {
        await _respond(request, 'Not Found', status: HttpStatus.notFound);
        return;
      }
      if (params['state'] != state) {
        await _respond(request, '该响应不对应，请回到客户端重试！');
        return;
      }
      final ticket = params['ticket'];
      if (ticket == null || ticket.isEmpty) {
        await _respond(
          request,
          '授权未返回票据，请重新登录！',
          status: HttpStatus.badRequest,
        );
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      await _respond(request, '已完成授权，可以关闭本页面并返回 TouchFish Client 客户端');
      if (!completer.isCompleted) completer.complete(ticket);
    });
    return completer.future
        .timeout(timeout, onTimeout: () => null)
        .whenComplete(() => subscription.cancel());
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _respond(
    HttpRequest request,
    String message, {
    int status = 200,
  }) async {
    final response = request.response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..write(_closingPage(message));
    await response.close();
  }
  static String _closingPage(String message) => '''
<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TouchFish</title>
<body style="margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
background:#0f1115;color:#e8eaed;font-family:system-ui,-apple-system,'Segoe UI',sans-serif">
<div style="text-align:center;padding:24px">
<p style="font-size:16px;line-height:1.7;margin:0">$message</p>
</div></body></html>
''';
}
