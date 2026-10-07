import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../utils/talker.dart';

/// C A P T C H A 114514
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
  String? _error;

  void _onWebViewCreated(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'captchaDone',
      callback: (args) {
        final token = args.isNotEmpty ? args.first?.toString() : null;
        if (token == null || token.isEmpty) return;
        if (mounted) Navigator.pop(context, token);
      },
    );
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
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.pageUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
              ),
              onWebViewCreated: _onWebViewCreated,
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame == true) {
                  talker.error(
                    'ThirdPartyCaptchaSheet error: ${error.description}',
                  );
                  if (mounted) {
                    setState(() => _error = error.description);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
