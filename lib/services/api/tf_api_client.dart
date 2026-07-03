import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tf_crypto.dart';
import '../../constants/app_constants.dart';
import '../../models/user_profile.dart';
import '../../models/forum_model.dart';
import '../../models/announcement_model.dart';
import '../server_connection_status_service.dart';
import '../../widgets/server_selector.dart';
import '../../utils/talker.dart';

class TfServerConfig {
  final bool captcha;
  final bool emailActivate;
  final int portApi;
  final int portTcp;
  final String serverName;
  final int? fileLastTime;
  final int? groupsLimit;
  final int? singleGroupMaxPeople;
  final int? maxFileSize;
  final String? verifyEmail;
  final Map<String, dynamic>? rateLimits;
  final Map<String, String> defaultAssetUrls;

  const TfServerConfig({
    required this.captcha,
    required this.emailActivate,
    required this.portApi,
    required this.portTcp,
    required this.serverName,
    this.fileLastTime,
    this.groupsLimit,
    this.singleGroupMaxPeople,
    this.maxFileSize,
    this.verifyEmail,
    this.rateLimits,
    this.defaultAssetUrls = const {},
  });

  static int _parseIntValue(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString()) ?? fallback;
  }

  static int? _parseOptionalIntValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  factory TfServerConfig.fromJson(Map<String, dynamic> json) {
    final defaultAssetUrlsRaw = json['default_asset_urls'];
    final defaultAssetUrls = defaultAssetUrlsRaw is Map
        ? defaultAssetUrlsRaw.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : const <String, String>{};

    return TfServerConfig(
      captcha: json['captcha'] as bool? ?? false,
      emailActivate: json['email_activate'] as bool? ?? false,
      portApi: _parseIntValue(json['port_api'], 7001),
      portTcp: _parseIntValue(json['port_tcp'], 1145),
      serverName: json['server_name'] as String? ?? 'TouchFish',
      fileLastTime: _parseOptionalIntValue(json['file_last_time']),
      groupsLimit: _parseOptionalIntValue(json['groups_limit']),
      singleGroupMaxPeople: _parseOptionalIntValue(
        json['single_group_max_people'],
      ),
      maxFileSize: _parseOptionalIntValue(json['max_file_size']),
      verifyEmail: json['verify_email'] as String?,
      rateLimits: json['rate_limits'] is Map
          ? Map<String, dynamic>.from(json['rate_limits'] as Map)
          : null,
      defaultAssetUrls: defaultAssetUrls,
    );
  }
}

class TfCaptchaInfo {
  final String pic; // base64 encoded png
  final String stamp; // captcha identifier token

  const TfCaptchaInfo({required this.pic, required this.stamp});
}

enum TfDebugRequestMethod { get, post }

class TfDebugRequestResult {
  final TfDebugRequestMethod method;
  final bool requestEncrypted;
  final String requestUrl;
  final String requestPayload;
  final int? statusCode;
  final String? rawResponseBody;
  final String? decodedResponseBody;
  final String? errorMessage;

  const TfDebugRequestResult({
    required this.method,
    required this.requestEncrypted,
    required this.requestUrl,
    required this.requestPayload,
    this.statusCode,
    this.rawResponseBody,
    this.decodedResponseBody,
    this.errorMessage,
  });
}

class _PreparedSecretPostRequest {
  final String requestUrl;
  final String requestBody;
  final Uint8List aesKey;

  const _PreparedSecretPostRequest({
    required this.requestUrl,
    required this.requestBody,
    required this.aesKey,
  });
}

/// TFV5 API CLIENT
class TfApiClient {
  static const _defaultTimeout = Duration(seconds: 10);
  static const _secretPostTimeout = Duration(seconds: 15);
  static const _probeTimeout = Duration(seconds: 5);

  static TfApiClient? _instance;
  static TfApiClient get instance => _instance ??= TfApiClient._();
  TfApiClient._();

  final _http = http.Client();

  RSAPublicKey? _cachedPubKey;
  String? _cachedBaseUrl;

  void _handleConnectivityFailure() {
    final statusService = ServerConnectionStatusService.instance;
    if (statusService.isProbing) {
      return;
    }

    statusService.reportConnectionLost(retryHandler: _probeServerConnection);
  }

  Future<http.Response> _getRequest(
    String url, {
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      final response = await _http.get(Uri.parse(url)).timeout(timeout);
      ServerConnectionStatusService.instance.reportReachable();
      return response;
    } on TimeoutException {
      _handleConnectivityFailure();
      rethrow;
    } on SocketException {
      _handleConnectivityFailure();
      rethrow;
    } on http.ClientException {
      _handleConnectivityFailure();
      rethrow;
    }
  }

  Future<http.Response> _postRequest(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      final response = await _http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(timeout);
      ServerConnectionStatusService.instance.reportReachable();
      return response;
    } on TimeoutException {
      _handleConnectivityFailure();
      rethrow;
    } on SocketException {
      _handleConnectivityFailure();
      rethrow;
    } on http.ClientException {
      _handleConnectivityFailure();
      rethrow;
    }
  }

  Future<bool> _probeServerConnection() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _getRequest(
        '$baseUrl/info',
        timeout: _probeTimeout,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    final prefs = await SharedPreferences.getInstance();
    final serversJson = prefs.getStringList('serversV2');
    final selectedIndex = prefs.getInt('selectedServerIndex') ?? 0;

    if (serversJson != null && serversJson.isNotEmpty) {
      final idx = selectedIndex.clamp(0, serversJson.length - 1);
      final serverInfo = ServerInfo.fromJson(jsonDecode(serversJson[idx]));
      final port = serverInfo.apiPort.isNotEmpty
          ? serverInfo.apiPort
          : AppConstants.defaultApiPort.toString();
      final scheme = serverInfo.useHttps ? 'https' : 'http';
      _cachedBaseUrl = '$scheme://${serverInfo.address}:$port';
      return _cachedBaseUrl!;
    }
    final defaultScheme =
        AppConstants.defaultUseHttps ? 'https' : 'http';
    _cachedBaseUrl =
        '$defaultScheme://${AppConstants.defaultServerAddress}:${AppConstants.defaultApiPort}';
    return _cachedBaseUrl!;
  }

  void invalidateCache() {
    _cachedPubKey = null;
    _cachedBaseUrl = null;
  }

  Future<RSAPublicKey> _getRsaPublicKey(String baseUrl) async {
    if (_cachedPubKey != null && _cachedBaseUrl == baseUrl) {
      return _cachedPubKey!;
    }
    final response = await _getRequest('$baseUrl/get_rsa_pub');
    final pem = response.body;
    final pubKey = TfCrypto.parseRsaPublicKey(pem);
    _cachedPubKey = pubKey;
    _cachedBaseUrl = baseUrl;
    return pubKey;
  }

  String _normalizeApiPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return '/';
    }
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  Map<String, dynamic> _buildRequestBody(
    Map<String, dynamic> body, {
    int? uid,
    String? password,
  }) {
    final fullBody = Map<String, dynamic>.from(body);
    if (uid != null) fullBody['uid'] = uid;
    if (password != null) fullBody['password'] = password;
    return fullBody;
  }

  String _stringifyQueryValue(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String || value is num || value is bool) {
      return value.toString();
    }
    return jsonEncode(value);
  }

  Uri _buildRequestUri(
    String baseUrl,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final normalizedPath = _normalizeApiPath(path);
    final uri = Uri.parse('$baseUrl$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final mergedQueryParameters = Map<String, String>.from(uri.queryParameters);
    for (final entry in queryParameters.entries) {
      mergedQueryParameters[entry.key] = _stringifyQueryValue(entry.value);
    }

    return uri.replace(queryParameters: mergedQueryParameters);
  }

  Future<_PreparedSecretPostRequest> _prepareSecretPostRequest(
    String path,
    Map<String, dynamic> body, {
    int? uid,
    String? password,
  }) async {
    final baseUrl = await getBaseUrl();
    final requestUrl = _buildRequestUri(baseUrl, path).toString();
    final pubKey = await _getRsaPublicKey(baseUrl);

    final fullBody = _buildRequestBody(body, uid: uid, password: password);

    final aesKey = TfCrypto.generateAesKey();
    final iv = TfCrypto.generateIv();
    final encryptedContent = TfCrypto.aesEncrypt(
      jsonEncode(fullBody),
      aesKey,
      iv,
    );
    final encryptedAesKey = TfCrypto.rsaEncrypt(aesKey, pubKey);

    final requestBody = jsonEncode({
      'iv': base64.encode(iv),
      'key': base64.encode(encryptedAesKey),
      'content': base64.encode(encryptedContent),
    });

    return _PreparedSecretPostRequest(
      requestUrl: requestUrl,
      requestBody: requestBody,
      aesKey: aesKey,
    );
  }

  String _decryptSecretResponse(String responseBody, Uint8List aesKey) {
    final responseData = jsonDecode(responseBody) as Map<String, dynamic>;
    final responseIv = base64.decode(responseData['iv'] as String);
    final responseContent = base64.decode(responseData['content'] as String);
    return TfCrypto.aesDecrypt(responseContent, aesKey, responseIv);
  }

  Future<String?> secretPost(
    String path,
    Map<String, dynamic> body, {
    int? uid,
    String? password,
  }) async {
    try {
      final preparedRequest = await _prepareSecretPostRequest(
        path,
        body,
        uid: uid,
        password: password,
      );

      final response = await _postRequest(
        preparedRequest.requestUrl,
        headers: {'Content-Type': 'application/json'},
        body: preparedRequest.requestBody,
        timeout: _secretPostTimeout,
      );

      if (response.statusCode != 200) return null;

      return _decryptSecretResponse(response.body, preparedRequest.aesKey);
    } catch (e) {
      talker.error('secretPost $path failed', e);
      return null;
    }
  }

  Future<TfDebugRequestResult> debugRequest(
    TfDebugRequestMethod method,
    String path,
    Map<String, dynamic> body, {
    bool encryptRequest = true,
    int? uid,
    String? password,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final fullBody = _buildRequestBody(body, uid: uid, password: password);

      switch (method) {
        case TfDebugRequestMethod.get:
          final requestUrl = _buildRequestUri(
            baseUrl,
            path,
            queryParameters: fullBody,
          ).toString();
          final response = await _getRequest(
            requestUrl,
            timeout: _secretPostTimeout,
          );
          return TfDebugRequestResult(
            method: method,
            requestEncrypted: false,
            requestUrl: requestUrl,
            requestPayload: fullBody.isEmpty ? '' : jsonEncode(fullBody),
            statusCode: response.statusCode,
            rawResponseBody: response.body,
          );
        case TfDebugRequestMethod.post:
          if (!encryptRequest) {
            final requestUrl = _buildRequestUri(baseUrl, path).toString();
            final requestPayload = jsonEncode(fullBody);
            final response = await _postRequest(
              requestUrl,
              headers: {'Content-Type': 'application/json'},
              body: requestPayload,
              timeout: _secretPostTimeout,
            );

            return TfDebugRequestResult(
              method: method,
              requestEncrypted: false,
              requestUrl: requestUrl,
              requestPayload: requestPayload,
              statusCode: response.statusCode,
              rawResponseBody: response.body,
            );
          }

          final preparedRequest = await _prepareSecretPostRequest(
            path,
            body,
            uid: uid,
            password: password,
          );
          final response = await _postRequest(
            preparedRequest.requestUrl,
            headers: {'Content-Type': 'application/json'},
            body: preparedRequest.requestBody,
            timeout: _secretPostTimeout,
          );

          String? decodedResponseBody;
          String? errorMessage;
          if (response.statusCode == 200) {
            try {
              decodedResponseBody = _decryptSecretResponse(
                response.body,
                preparedRequest.aesKey,
              );
            } catch (e) {
              errorMessage = 'Failed to decrypt response: $e';
            }
          }

          return TfDebugRequestResult(
            method: method,
            requestEncrypted: true,
            requestUrl: preparedRequest.requestUrl,
            requestPayload: preparedRequest.requestBody,
            statusCode: response.statusCode,
            rawResponseBody: response.body,
            decodedResponseBody: decodedResponseBody,
            errorMessage: errorMessage,
          );
      }
    } catch (e, stackTrace) {
      talker.error('debugRequest $path failed', e, stackTrace);
      return TfDebugRequestResult(
        method: method,
        requestEncrypted:
            method == TfDebugRequestMethod.post && encryptRequest,
        requestUrl: '',
        requestPayload: '',
        errorMessage: e.toString(),
      );
    }
  }

  bool _parseBool(String? result) => result?.endsWith('True') ?? false;

  Map<String, dynamic>? _parseJsonMap(String? result) {
    if (result == null) {
      return null;
    }

    final trimmed = result.trim();
    if (!trimmed.startsWith('{')) {
      return null;
    }

    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  // server info

  Future<TfServerConfig?> fetchServerInfo() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _getRequest('$baseUrl/info');
      if (response.statusCode != 200) return null;
      return TfServerConfig.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      talker.error('fetchServerInfo failed', e);
      return null;
    }
  }

  Future<TfServerConfig?> queryServerSettings(int uid, String password) async {
    final result = await secretPost(
      '/auth/server_settings/query',
      const {},
      uid: uid,
      password: password,
    );

    final data = _parseJsonMap(result);
    if (data == null) {
      return null;
    }

    return TfServerConfig.fromJson(data);
  }

  Future<TfServerConfig?> updateServerSettings(
    int uid,
    String password, {
    required String serverName,
    required bool captcha,
    required int fileLastTime,
    required int groupsLimit,
    required int singleGroupMaxPeople,
    required int maxFileSize,
  }) async {
    final result = await secretPost(
      '/auth/server_settings/update',
      {
        'server_name': serverName,
        'captcha': captcha,
        'file_last_time': fileLastTime,
        'groups_limit': groupsLimit,
        'single_group_max_people': singleGroupMaxPeople,
        'max_file_size': maxFileSize,
      },
      uid: uid,
      password: password,
    );

    final data = _parseJsonMap(result);
    if (data == null) {
      return null;
    }

    return TfServerConfig.fromJson(data);
  }

  // captcha

  Future<TfCaptchaInfo?> getCaptcha() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _getRequest('$baseUrl/auth/captcha');
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.isEmpty) return null;
      return TfCaptchaInfo(
        pic: data['pic'] as String,
        stamp: data['stamp'].toString(),
      );
    } catch (e) {
      talker.error('getCaptcha failed', e);
      return null;
    }
  }

  // user

  Future<UserProfile?> getUserByUid(int uid, {int avatarVersion = 0}) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _getRequest('$baseUrl/auth/uid/$uid');
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.isEmpty) return null;
      return UserProfile.fromServerJson(
        data,
        '$baseUrl/avatar/get_avatar/user/$uid',
        avatarVersion: avatarVersion,
      );
    } catch (e) {
      talker.error('getUserByUid $uid failed', e);
      return null;
    }
  }

  Future<UserProfile?> getUserByUsername(String username, {int avatarVersion = 0}) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _getRequest('$baseUrl/auth/username/$username');
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.isEmpty) return null;
      final uid = data['uid'].toString();
      return UserProfile.fromServerJson(
        data,
        '$baseUrl/avatar/get_avatar/user/$uid',
        avatarVersion: avatarVersion,
      );
    } catch (e) {
      talker.error('getUserByUsername $username failed', e);
      return null;
    }
  }

  Future<bool> login(int uid, String password) async {
    final result = await secretPost(
      '/auth/login',
      {},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> register(
    String username,
    String password, {
    String? email,
    String? captchaStamp,
    String? captchaCode,
  }) async {
    final body = <String, dynamic>{'username': username, 'password': password};
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (captchaStamp != null) body['captcha_stamp'] = captchaStamp;
    if (captchaCode != null) body['captcha_code'] = captchaCode;
    final result = await secretPost('/auth/register', body);
    return _parseBool(result);
  }

  Future<bool> activateAccount(int uid, int activateCode) async {
    final result = await secretPost('/auth/activate', {
      'uid': uid,
      'activate_code': activateCode,
    });
    return _parseBool(result);
  }

  Future<bool> changeSign(int uid, String password, String newSign) async {
    final result = await secretPost(
      '/auth/change_sign',
      {'new_sign': newSign},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> changeIntroduction(
    int uid,
    String password,
    String newIntro,
  ) async {
    final result = await secretPost(
      '/auth/change_introduction',
      {'new_introduction': newIntro},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> changePassword(
    int uid,
    String password,
    String newPassword,
  ) async {
    final result = await secretPost(
      '/auth/change_pwd',
      {'new_pwd': newPassword},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> changeEmail(int uid, String password, String newEmail) async {
    final result = await secretPost(
      '/auth/change_email',
      {'new_email': newEmail},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> uploadUserAvatar(
    int uid,
    String password,
    String picBase64,
  ) async {
    final result = await secretPost(
      '/avatar/upload_user_avatar',
      {'pic': picBase64},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> uploadForumAvatar(
    int uid,
    String password,
    int fid,
    String picBase64,
  ) async {
    final result = await secretPost(
      '/avatar/upload_forum_avatar',
      {'fid': fid, 'pic': picBase64},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> uploadDefaultAvatar(
    int uid,
    String password,
    String assetType,
    String picBase64,
  ) async {
    final result = await secretPost(
      '/avatar/upload_default_avatar',
      {'type': assetType, 'pic': picBase64},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  // forum

  Future<List<Forum>> getForumList() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _getRequest('$baseUrl/forum/get_forum_list');
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is! List) return [];
      return data
          .map((row) => Forum.fromServerRow(row as List<dynamic>, baseUrl: baseUrl))
          .toList();
    } catch (e) {
      talker.error('getForumList failed', e);
      return [];
    }
  }

  Future<List<PendingForumApproval>> getApprovingForumList(
    int uid,
    String password,
  ) async {
    final result = await secretPost(
      '/forum/get_approving_forum_list',
      const {},
      uid: uid,
      password: password,
    );

    if (result == null) {
      throw Exception('Failed to fetch pending forums.');
    }
    if (_parseBool(result)) {
      throw Exception('Pending forums request was rejected.');
    }

    try {
      final data = jsonDecode(result);
      if (data is! Map) return const [];

      final approvals = <PendingForumApproval>[];
      for (final entry in data.entries) {
        if (entry.key == 'queue_num') continue;
        final rawValue = entry.value;
        if (rawValue is Map<String, dynamic>) {
          approvals.add(
            PendingForumApproval.fromQueueEntry(entry.key, rawValue),
          );
          continue;
        }
        if (rawValue is Map) {
          approvals.add(
            PendingForumApproval.fromQueueEntry(
              entry.key,
              Map<String, dynamic>.from(rawValue),
            ),
          );
        }
      }

      approvals.sort((left, right) => left.queueId.compareTo(right.queueId));
      return approvals;
    } catch (e) {
      talker.error('getApprovingForumList failed', e);
      throw Exception('Failed to parse pending forums.');
    }
  }

  Future<List<ForumPost>> getPostList(int fid) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _getRequest('$baseUrl/forum/get_post_list/$fid');
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is List) {
        // Legacy format: plain list of rows
        return data
            .map(
              (row) =>
                  ForumPost.fromServerRow(fid.toString(), row as List<dynamic>),
            )
            .toList();
      }
      if (data is Map) {
        final posts = data['posts'] as List? ?? [];
        final pinnedPid = data['pinned_pid'];
        return posts.map((row) {
          final post = ForumPost.fromServerRow(
            fid.toString(),
            row as List<dynamic>,
          );
          if (pinnedPid != null && post.id == pinnedPid.toString()) {
            return post.copyWith(isPinned: true);
          }
          return post;
        }).toList();
      }
      return [];
    } catch (e) {
      talker.error('getPostList $fid failed', e);
      return [];
    }
  }

  Future<bool> sendPost(
    int uid,
    String password,
    int fid,
    String title,
    String content,
  ) async {
    final result = await secretPost(
      '/forum/send_post',
      {'fid': fid, 'title': title, 'content': content},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> removePost(int uid, String password, int fid, int pid) async {
    final result = await secretPost(
      '/forum/remove_post',
      {'fid': fid, 'pid': pid},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> removeForum(int uid, String password, int fid) async {
    final result = await secretPost(
      '/forum/remove_forum',
      {'fid': fid},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<List<ForumComment>> getAllComments(int fid, int pid) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _getRequest(
        '$baseUrl/forum/get_all_comments/$fid/$pid',
      );
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is! Map) return [];
      final comments = <ForumComment>[];
      (data as Map<String, dynamic>).forEach((timestamp, value) {
        final items = value as List<dynamic>;
        final ms = (double.tryParse(timestamp) ?? 0) * 1000;
        comments.add(
          ForumComment(
            id: timestamp,
            postId: pid.toString(),
            authorUid: items[0].toString(),
            content: items[1] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
          ),
        );
      });
      comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return comments;
    } catch (e) {
      talker.error('getAllComments $fid/$pid failed', e);
      return [];
    }
  }

  Future<bool> addComment(
    int uid,
    String password,
    int fid,
    int pid,
    String comment,
  ) async {
    final result = await secretPost(
      '/forum/comment',
      {'fid': fid, 'pid': pid, 'comment': comment},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> removeComment(
    int uid,
    String password,
    int fid,
    int pid,
    String sendTime,
  ) async {
    final result = await secretPost(
      '/forum/remove_comment',
      {'fid': fid, 'pid': pid, 'send_time': sendTime},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> pinPost(int uid, String password, int fid, int pid) async {
    final result = await secretPost(
      '/forum/pin_post',
      {'fid': fid, 'pid': pid},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> unpinPost(int uid, String password, int fid) async {
    final result = await secretPost(
      '/forum/unpin_post',
      {'fid': fid},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  // --- forum members ---

  // Helper to detect boolean responses from server (ends with True/False)
  bool _isBoolResponse(String? result) {
    if (result == null) return false;
    return result.endsWith('True') || result.endsWith('False');
  }

  Future<List<ForumMember>> getMembers(int uid, String password, int fid) async {
    final result = await secretPost(
      '/forum/members',
      {'fid': fid},
      uid: uid,
      password: password,
    );
    if (result == null) return [];
    if (_isBoolResponse(result)) return []; // access denied or boolean response
    try {
      final list = jsonDecode(result) as List;
      return list
          .map((row) => ForumMember.fromServerRow(row as List<dynamic>))
          .toList();
    } catch (e) {
      talker.error('getMembers parse failed', e);
      return [];
    }
  }

  Future<bool> addMember(
    int uid, String password, int fid, int targetUid, int role,
  ) async {
    final result = await secretPost(
      '/forum/add_member',
      {'fid': fid, 'target_uid': targetUid, 'role': role},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> removeMember(
    int uid, String password, int fid, int targetUid,
  ) async {
    final result = await secretPost(
      '/forum/remove_member',
      {'fid': fid, 'target_uid': targetUid},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> changeMemberRole(
    int uid, String password, int fid, int targetUid, int newRole,
  ) async {
    final result = await secretPost(
      '/forum/change_member_role',
      {'fid': fid, 'target_uid': targetUid, 'new_role': newRole},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> editForum(
    int uid, String password, int fid, {
    String? forumName,
    String? introduction,
  }) async {
    final body = <String, dynamic>{'fid': fid};
    if (forumName != null) body['forum_name'] = forumName;
    if (introduction != null) body['introduction'] = introduction;
    final result = await secretPost(
      '/forum/edit_forum',
      body,
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  // --- self join / leave ---

  Future<bool> joinForum(int uid, String password, int fid) async {
    final result = await secretPost(
      '/forum/join',
      {'fid': fid},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> leaveForumApi(int uid, String password, int fid) async {
    final result = await secretPost(
      '/forum/leave',
      {'fid': fid},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  /// Returns list of [fid, role] pairs.
  Future<List<Map<String, int>>> getMyMemberships(int uid, String password) async {
    final result = await secretPost(
      '/forum/my_memberships',
      {},
      uid: uid,
      password: password,
    );
    if (result == null) return [];
    if (_isBoolResponse(result)) return [];
    try {
      final list = jsonDecode(result) as List;
      return list.map((row) {
        final r = row as List<dynamic>;
        return {'fid': (r[0] as num).toInt(), 'role': (r[1] as num).toInt()};
      }).toList();
    } catch (e) {
      talker.error('getMyMemberships parse failed', e);
      return [];
    }
  }

  Future<bool> createForum(
    int uid,
    String password,
    String forumName,
    String introduction,
  ) async {
    final result = await secretPost(
      '/forum/create_forum',
      {'forum_name': forumName, 'introduction': introduction},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> approveForum(int uid, String password, int queueId) async {
    final result = await secretPost(
      '/forum/approve_forum',
      {'qid': queueId},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> rejectForum(
    int uid,
    String password,
    int queueId, {
    String? reason,
  }) async {
    final normalizedReason = reason?.trim();
    final result = await secretPost(
      '/forum/reject_forum',
      {
        'qid': queueId,
        if (normalizedReason != null && normalizedReason.isNotEmpty)
          'reason': normalizedReason,
      },
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  // announcement

  Future<List<Announcement>> getAnnouncements() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _getRequest('$baseUrl/announcement/query_all');
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data.entries
          .map((e) => Announcement.fromJson(
                e.key,
                e.value as Map<String, dynamic>,
              ))
          .toList();
      list.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
      return list;
    } catch (e) {
      talker.error('getAnnouncements failed', e);
      return [];
    }
  }

  Future<bool> createAnnouncement(int uid, String password, String content) async {
    final result = await secretPost(
      '/announcement/upload_announcement',
      {'content': content},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> deleteAnnouncement(int uid, String password, String timeStamp) async {
    final result = await secretPost(
      '/announcement/delete_announcement',
      {'time_stamp': timeStamp},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }
}
