import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tf_crypto.dart';
import '../../models/message_model.dart';
import '../../constants/app_constants.dart';
import '../../models/user_profile.dart';
import '../../models/forum_model.dart';
import '../../models/announcement_model.dart';
import '../../models/notification_model.dart';
import '../server_connection_status_service.dart';
import '../../widgets/server_selector.dart';
import '../../utils/talker.dart';

class TfChatListItem {
  final String roomId;
  final String roomType;
  final int partnerUid;
  final String username;
  final String? avatar;
  final String? lastContent;
  final String? lastContentType;
  final double? lastTime;
  final int? lastSenderUid;
  final int? lastMid;
  final bool isFriend;

  const TfChatListItem({
    required this.roomId,
    required this.roomType,
    required this.partnerUid,
    required this.username,
    this.avatar,
    this.lastContent,
    this.lastContentType,
    this.lastTime,
    this.lastSenderUid,
    this.lastMid,
    required this.isFriend,
  });

  factory TfChatListItem.fromJson(Map<String, dynamic> json) {
    return TfChatListItem(
      roomId: json['room_id'] as String? ?? '',
      roomType: json['room_type'] as String? ?? 'direct',
      partnerUid: (json['partner_uid'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      avatar: json['avatar'] as String?,
      lastContent: json['last_content'] as String?,
      lastContentType: json['last_content_type'] as String?,
      lastTime: (json['last_time'] as num?)?.toDouble(),
      lastSenderUid: (json['last_sender_uid'] as num?)?.toInt(),
      lastMid: (json['last_mid'] as num?)?.toInt(),
      isFriend: json['is_friend'] as bool? ?? false,
    );
  }
}

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
  final int? maxMessageLength;
  final int minGroupNameLength;
  final int maxGroupNameLength;
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
    this.maxMessageLength,
    this.minGroupNameLength = 1,
    this.maxGroupNameLength = 50,
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
      maxMessageLength: _parseOptionalIntValue(json['max_message_length']),
      minGroupNameLength: _parseIntValue(json['min_group_name_length'], 1),
      maxGroupNameLength: _parseIntValue(json['max_group_name_length'], 50),
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

class UserManagePagination {
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final bool hasMore;

  const UserManagePagination({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  factory UserManagePagination.fromJson(Map<String, dynamic> json) {
    return UserManagePagination(
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      totalPages: (json['total_pages'] as num).toInt(),
      hasMore: json['has_more'] as bool,
    );
  }
}

class UserManageResult {
  final List<UserProfile> users;
  final UserManagePagination pagination;

  const UserManageResult({required this.users, required this.pagination});
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
  TfServerConfig? _cachedServerConfig;

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

  Future<bool> _canReachUrl(
    String url, {
    Duration timeout = _probeTimeout,
  }) async {
    try {
      final response = await _http.get(Uri.parse(url)).timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// probe！
  Future<bool> probeServer(ServerInfo? server) async {
    try {
      final baseUrl = await _resolveBaseUrlFor(server);
      return await _canReachUrl('$baseUrl/info');
    } catch (_) {
      return false;
    }
  }

  Future<bool> probeConnection() async {
    try {
      final baseUrl = await getBaseUrl();
      return await _canReachUrl('$baseUrl/info');
    } catch (_) {
      return false;
    }
  }

  Future<ServerInfo?> _loadSelectedServer() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = prefs.getStringList('serversV2');
    final selectedIndex = prefs.getInt('selectedServerIndex') ?? 0;
    if (serversJson != null && serversJson.isNotEmpty) {
      final idx = selectedIndex.clamp(0, serversJson.length - 1);
      return ServerInfo.fromJson(jsonDecode(serversJson[idx]));
    }
    return null;
  }

  Future<String> _resolveBaseUrlFor(ServerInfo? server) async {
    final address = (server != null && server.address.isNotEmpty)
        ? server.address
        : AppConstants.defaultServerAddress;
    final port = (server != null && server.apiPort.isNotEmpty)
        ? server.apiPort
        : AppConstants.defaultApiPort.toString();
    final useHttps = server?.useHttps ?? AppConstants.defaultUseHttps;

    if (useHttps) {
      final httpsUrl = 'https://$address:$port';
      if (await _canReachUrl('$httpsUrl/info')) {
        return httpsUrl;
      }
      return 'http://$address:$port';
    }

    return 'http://$address:$port';
  }

  Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    final serverInfo = await _loadSelectedServer();
    _cachedBaseUrl = await _resolveBaseUrlFor(serverInfo);
    return _cachedBaseUrl!;
  }


  Future<int> resolveTcpPort() async {
    final serverInfo = await _loadSelectedServer();
    final autoDetect =
        serverInfo?.autoDetectTcpPort ?? AppConstants.defaultAutoDetectTcpPort;
    if (autoDetect) {
      final config = await fetchServerInfo();
      if (config != null) return config.portTcp;
    }
    final raw = serverInfo?.tcpPort ?? '';
    return int.tryParse(raw) ?? AppConstants.defaultTcpPort;
  }

  Future<bool> shouldTryWss() async {
    final serverInfo = await _loadSelectedServer();
    return serverInfo?.tryWss ?? AppConstants.defaultTryWss;
  }

  void invalidateCache() {
    _cachedPubKey = null;
    _cachedBaseUrl = null;
    _cachedServerConfig = null;
  }

  Future<int?> getMaxFileSize() async {
    _cachedServerConfig ??= await fetchServerInfo();
    final limit = _cachedServerConfig?.maxFileSize;
    if (limit == null || limit == -1) return null;
    return limit;
  }

  Future<RSAPublicKey> getRsaPublicKey() async {
    final baseUrl = await getBaseUrl();
    return _getRsaPublicKey(baseUrl);
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
      final config = TfServerConfig.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      _cachedServerConfig = config;
      return config;
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
    required int maxMessageLength,
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
        'max_message_length': maxMessageLength,
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

  Future<bool> uploadGroupAvatar(
    int uid,
    String password,
    int gid,
    String picBase64,
  ) async {
    final result = await secretPost(
      '/avatar/upload_group_avatar',
      {'gid': gid, 'pic': picBase64},
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

  // notification

  Future<List<NotificationInfo>> queryAllNotifications(
    int uid,
    String password,
  ) async {
    final result = await secretPost(
      '/notification/query_all',
      {},
      uid: uid,
      password: password,
    );
    if (result == null) return [];
    try {
      final list = jsonDecode(result) as List<dynamic>;
      return list
          .map((e) => NotificationInfo.fromServerJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      talker.error('queryAllNotifications parse failed', e);
      return [];
    }
  }

  Future<List<NotificationInfo>> queryNotificationsAfter(
    int uid,
    String password,
    double timeStamp,
  ) async {
    final result = await secretPost(
      '/notification/query_after',
      {'time_stamp': timeStamp},
      uid: uid,
      password: password,
    );
    if (result == null) return [];
    try {
      final list = jsonDecode(result) as List<dynamic>;
      return list
          .map((e) => NotificationInfo.fromServerJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      talker.error('queryNotificationsAfter parse failed', e);
      return [];
    }
  }

  Future<bool> deleteNotificationsBefore(
    int uid,
    String password,
    double timeStamp,
  ) async {
    final result = await secretPost(
      '/notification/delete_before',
      {'time_stamp': timeStamp},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> deleteAllNotifications(int uid, String password) async {
    final result = await secretPost(
      '/notification/delete_all',
      {},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  // friend

  Future<bool> addFriend(
    int uid,
    String password,
    int targetUid,
    String reqWord,
  ) async {
    final result = await secretPost(
      '/friend/add_friend',
      {'added': targetUid, 'req_word': reqWord},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> dealFriendShip(
    int uid,
    String password,
    int dealtUid,
    String stat,
  ) async {
    final result = await secretPost(
      '/friend/deal_ship',
      {'dealt': dealtUid, 'stat': stat},
      uid: uid,
      password: password,
    );
    talker.info('dealFriendShip: uid=$uid dealt=$dealtUid stat=$stat rawResult=$result parsed=${_parseBool(result)}');
    return _parseBool(result);
  }

  Future<List<int>> getFriendList(int uid, String password) async {
    final result = await secretPost(
      '/friend/list',
      {},
      uid: uid,
      password: password,
    );
    if (result == null) return [];
    try {
      final list = jsonDecode(result) as List<dynamic>;
      return list.map((e) => (e as num).toInt()).toList();
    } catch (e) {
      talker.error('getFriendList parse failed', e);
      return [];
    }
  }

  /// Unified message send — returns {mid, status: 'sent'} or null.
  Future<Map<String, dynamic>?> sendMessage(
    int uid, String password, {
    required String recipient, // "U123" or "G456"
    required String content,
    String contentType = 'plain',
    String? clientMid,
    String? fileHash,
    int quote = -1,
  }) async {
    final result = await secretPost('/message/send', {
      'recipient': recipient,
      'content': content,
      'content_type': contentType,
      'client_mid': clientMid,
      'file_hash': fileHash,
      'quote': quote,
    }, uid: uid, password: password);
    try {
      final data = jsonDecode(result ?? '');
      if (data is Map<String, dynamic>) return data;
    } catch (_) {}
    return null;
  }

  /// Fetch the chat room list with last message and partner profile.
  Future<List<TfChatListItem>> queryChatList(int uid, String password) async {
    final result = await secretPost(
      '/chat/list',
      {},
      uid: uid,
      password: password,
    );
    if (result == null) return [];
    try {
      final decoded = jsonDecode(result);
      if (decoded is Map<String, dynamic> && decoded.containsKey('error')) {
        talker.warning('queryChatList server error: ${decoded['error']}');
        return [];
      }
      final list = decoded as List<dynamic>;
      return list
          .map((e) => TfChatListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      talker.error('queryChatList parse failed', e);
      return [];
    }
  }

  /// Fetch paginated message history. Pass [groupId] for group chats.
  Future<List<ChatMessage>> queryMessageHistory(
    int uid,
    String password,
    int targetUid, {
    int? groupId,
    int beforeMid = 0,
    int limit = 50,
  }) async {
    final body = <String, dynamic>{
      'target_uid': targetUid,
      'before_mid': beforeMid,
      'limit': limit,
    };
    if (groupId != null) body['group_id'] = groupId;

    final result = await secretPost(
      '/message/history',
      body,
      uid: uid,
      password: password,
    );
    if (result == null) return [];
    try {
      final list = jsonDecode(result) as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromMessageRecord(e as Map<String, dynamic>, uid))
          .toList();
    } catch (e) {
      talker.error('queryMessageHistory parse failed', e);
      return [];
    }
  }

  // --- group management ---

  Future<int?> createGroup(int uid, String password,
      {required String groupname, String introduction = '', String enterHint = '',
       bool allowDirectJoin = false, bool requireReview = true}) async {
    final result = await secretPost('/group/create_group', {
      'groupname': groupname,
      'introduction': introduction,
      'enter_hint': enterHint,
      'allow_direct_join': allowDirectJoin,
      'require_review': requireReview,
    }, uid: uid, password: password);
    final data = _parseJsonMap(result);
    return (data?['gid'] as num?)?.toInt();
  }

  Future<Map<String, dynamic>?> getGroupSettings(int uid, String password, int gid) async {
    final result = await secretPost('/group/settings', {'gid': gid},
        uid: uid, password: password);
    return _parseJsonMap(result);
  }

  Future<bool> updateGroupSettings(int uid, String password, int gid, Map<String, dynamic> updates) async {
    final body = <String, dynamic>{'gid': gid};
    body.addAll(updates);
    final result = await secretPost('/group/update_settings', body,
        uid: uid, password: password);
    return _parseBool(result);
  }

  Future<Map<String, dynamic>?> getGroupMembers(int uid, String password, int gid) async {
    final result = await secretPost('/group/members', {'gid': gid},
        uid: uid, password: password);
    return _parseJsonMap(result);
  }

  Future<bool> transferGroupOwner(int uid, String password, int gid, int newOwner) async {
    final result = await secretPost('/group/transfer_owner',
        {'gid': gid, 'new_owner': newOwner},
        uid: uid, password: password);
    return _parseBool(result);
  }

  Future<bool> setGroupAdmin(int uid, String password, int gid, int targetUid, bool isAdmin) async {
    final endpoint = isAdmin ? '/group/add_admin' : '/group/remove_admin';
    final key = isAdmin ? 'added' : 'removed';
    final result = await secretPost(endpoint, {'gid': gid, key: targetUid},
        uid: uid, password: password);
    return _parseBool(result);
  }

  Future<bool> removeGroupMember(int uid, String password, int gid, int targetUid) async {
    final result = await secretPost('/group/remove_member',
        {'gid': gid, 'removed': targetUid},
        uid: uid, password: password);
    return _parseBool(result);
  }

  Future<Map<String, dynamic>?> joinGroup(int uid, String password, int gid) async {
    final result = await secretPost('/group/join', {'gid': gid},
        uid: uid, password: password);
    return _parseJsonMap(result);
  }

  Future<Map<String, dynamic>?> inviteToGroup(int uid, String password, int gid, int invitedUid) async {
    final result = await secretPost('/group/invite',
        {'gid': gid, 'invited_uid': invitedUid},
        uid: uid, password: password);
    return _parseJsonMap(result);
  }

  Future<List<Map<String, dynamic>>> getJoinRequests(int uid, String password, int gid) async {
    final result = await secretPost('/group/join_requests', {'gid': gid},
        uid: uid, password: password);
    if (result == null) return [];
    try {
      return (jsonDecode(result) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> handleJoinRequest(int uid, String password, int rid, bool approved) async {
    final result = await secretPost('/group/handle_join_request',
        {'rid': rid, 'approved': approved},
        uid: uid, password: password);
    return _parseBool(result);
  }

  // --- account management (admin) ---

  Future<UserManageResult?> manageListUsers(
    int uid,
    String password, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final baseUrl = await getBaseUrl();
    final result = await secretPost(
      '/auth/manage/list',
      {'page': page, 'page_size': pageSize},
      uid: uid,
      password: password,
    );

    if (result == null) return null;

    try {
      final data = jsonDecode(result);
      if (data is! Map<String, dynamic>) return null;

      final usersRaw = data['users'] as List<dynamic>?;
      if (usersRaw == null) return null;

      final users = usersRaw.map((u) {
        final userJson = u as Map<String, dynamic>;
        final userUid = userJson['uid'].toString();
        return UserProfile.fromServerJson(
          userJson,
          '$baseUrl/avatar/get_avatar/user/$userUid',
        );
      }).toList();

      final pagination = UserManagePagination.fromJson(
        data['pagination'] as Map<String, dynamic>,
      );

      return UserManageResult(users: users, pagination: pagination);
    } catch (e) {
      talker.error('manageListUsers parse failed', e);
      return null;
    }
  }

  Future<bool> manageChangeAuth(
    int uid,
    String password,
    int targetUid,
    String newAuth,
  ) async {
    final result = await secretPost(
      '/auth/change_auth',
      {'change_uid': targetUid, 'new_auth': newAuth},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> manageBanUser(
    int uid,
    String password,
    int targetUid,
  ) async {
    final result = await secretPost(
      '/auth/manage/ban',
      {'change_uid': targetUid},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> manageDeleteUser(
    int uid,
    String password,
    int targetUid,
  ) async {
    final result = await secretPost(
      '/auth/manage/delete',
      {'change_uid': targetUid},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  // --- file management ---

  Future<Map<String, dynamic>?> uploadFile(
    int uid,
    String password,
    String fileName,
    String fileBase64,
  ) async {
    final result = await secretPost(
      '/file/upload_file',
      {
        'filename': fileName,
        'file_b64': fileBase64,
      },
      uid: uid,
      password: password,
    );

    final data = _parseJsonMap(result);
    if (data == null) return null;

    final success = data['success'];
    if (success is bool && !success) return null;

    return data;
  }

  Future<List<Map<String, dynamic>>> getUserFiles(
    int uid,
    String password,
  ) async {
    final result = await secretPost(
      '/file/get_user_files',
      {},
      uid: uid,
      password: password,
    );

    if (result == null) return [];

    try {
      final data = jsonDecode(result);
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      talker.error('getUserFiles parse failed', e);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStorageInfo(
    int uid,
    String password,
  ) async {
    final result = await secretPost(
      '/file/get_storage_info',
      {},
      uid: uid,
      password: password,
    );

    final data = _parseJsonMap(result);
    return data;
  }

  Future<bool> deleteFile(int uid, String password, String hash) async {
    final result = await secretPost(
      '/file/delete_file',
      {'hash': hash},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<List<Map<String, dynamic>>> adminGetAllFiles(
    int uid,
    String password, {
    int? targetUid,
  }) async {
    final body = <String, dynamic>{};
    if (targetUid != null) body['target_uid'] = targetUid;

    final result = await secretPost(
      '/file/admin_get_all_files',
      body,
      uid: uid,
      password: password,
    );

    if (result == null) return [];

    try {
      final data = jsonDecode(result);
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      talker.error('adminGetAllFiles parse failed', e);
      return [];
    }
  }

  Future<bool> adminForceDeleteFile(
    int uid,
    String password,
    String hash,
  ) async {
    final result = await secretPost(
      '/file/admin_force_delete_file',
      {'hash': hash},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }
}
