import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Future<String?> cacheNotificationAvatarAttachment(String? avatarUrl) async {
  if (avatarUrl == null || !avatarUrl.startsWith('http')) return null;
  try {
    final response = await http
        .get(Uri.parse(avatarUrl))
        .timeout(const Duration(seconds: 3));
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.bodyBytes.isEmpty ||
        response.bodyBytes.length > 2 * 1024 * 1024) {
      return null;
    }
    final cacheDirectory = await getTemporaryDirectory();
    final target = File(
      '${cacheDirectory.path}${Platform.pathSeparator}notification-avatar-${avatarUrl.hashCode.abs()}.jpg',
    );
    await target.writeAsBytes(response.bodyBytes, flush: false);
    return target.path;
  } catch (_) {
    return null;
  }
}
