import 'dart:async';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../utils/talker.dart';

/// Web be like
class ThirdPartyCaptchaSheet extends StatefulWidget {
  final String pageUrl;

  const ThirdPartyCaptchaSheet({super.key, required this.pageUrl});

  static Future<String?> show(BuildContext context, String pageUrl) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ThirdPartyCaptchaSheet(pageUrl: pageUrl),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<ThirdPartyCaptchaSheet> createState() => _ThirdPartyCaptchaSheetState();
}

class _ThirdPartyCaptchaSheetState extends State<ThirdPartyCaptchaSheet> {
  static int _viewTypeSequence = 0;

  // viewType 每次打开都必须不同
  final String _viewType = 'captcha-iframe-${_viewTypeSequence++}';

  web.HTMLIFrameElement? _iframe;
  StreamSubscription? _messageSubscription;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _setupIframe);
  }

  void _setupIframe() {
    if (!mounted) return;
    _messageSubscription = web.window.onMessage.listen((event) {
      final data = event.data;
      if (data == null) return;
      final message = data.toString();
      talker.debug('ThirdPartyCaptchaSheet onMessage: $message');
      if (message.startsWith('captcha_tk=')) {
        final token = message.substring('captcha_tk='.length);
        if (token.isEmpty) return;
        if (mounted) Navigator.pop(context, token);
      }
    });

    final iframe = web.HTMLIFrameElement()
      ..src = widget.pageUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    _iframe = iframe;

    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => iframe,
    );

    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _iframe?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isInitialized
          ? HtmlElementView(viewType: _viewType)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
