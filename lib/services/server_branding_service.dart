import 'package:flutter/foundation.dart';

import '../utils/talker.dart';
import 'api/tf_api_client.dart';

/// ServerBranding！Outstanding！
class ServerBrandingService extends ChangeNotifier {
  ServerBrandingService._();

  static final ServerBrandingService instance = ServerBrandingService._();

  String? _serverName;
  String? _logoUrl;
  bool _online = false;
  int _refreshToken = 0;

  String? get serverName => _serverName;
  String? get logoUrl => _logoUrl;
  bool get isOnline => _online;

  Future<void> refresh() async {
    final token = ++_refreshToken;
    try {
      final baseUrl = await TfApiClient.instance.getBaseUrl();
      final info = await TfApiClient.instance.fetchServerInfo();
      if (token != _refreshToken) return;

      final logoPath = info?.defaultAssetUrls['logo'];
      String? logoUrl;
      if (logoPath != null && logoPath.trim().isNotEmpty) {
        final rawUrl = logoPath.startsWith('http')
            ? logoPath
            : '$baseUrl$logoPath';
        final uri = Uri.tryParse(rawUrl);
        if (uri != null) {
          final queryParameters = Map<String, String>.from(
            uri.queryParameters,
          );
          queryParameters['v'] = DateTime.now()
              .millisecondsSinceEpoch
              .toString();
          logoUrl = uri.replace(queryParameters: queryParameters).toString();
        } else {
          logoUrl = rawUrl;
        }
      }

      _serverName = (info?.serverName.trim().isNotEmpty ?? false)
          ? info!.serverName.trim()
          : null;
      _logoUrl = logoUrl;
      _online = info != null;
      notifyListeners();
    } catch (e, stackTrace) {
      if (token != _refreshToken) return;
      talker.warning('ServerBrandingService.refresh failed', e, stackTrace);
      _serverName = null;
      _logoUrl = null;
      _online = false;
      notifyListeners();
    }
  }

  Future<void> reset() async {
    _refreshToken++;
    _serverName = null;
    _logoUrl = null;
    _online = false;
    notifyListeners();
  }
}
