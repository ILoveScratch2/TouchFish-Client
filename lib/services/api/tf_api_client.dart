import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tf_crypto.dart';
import '../../constants/app_constants.dart';
import '../../models/user_profile.dart';
import '../../models/forum_model.dart';
import '../../widgets/server_selector.dart';
import '../../utils/talker.dart';


class TfServerConfig {
  final bool captcha;
  final bool emailActivate;
  final int portApi;
  final int portTcp;
  final String serverName;

  const TfServerConfig({
    required this.captcha,
    required this.emailActivate,
    required this.portApi,
    required this.portTcp,
    required this.serverName,
  });

  factory TfServerConfig.fromJson(Map<String, dynamic> json) {
    return TfServerConfig(
      captcha: json['captcha'] as bool? ?? false,
      emailActivate: json['email_activate'] as bool? ?? false,
      portApi: json['port_api'] is int
          ? json['port_api'] as int
          : int.tryParse(json['port_api'].toString()) ?? 7001,
      portTcp: json['port_tcp'] is int
          ? json['port_tcp'] as int
          : int.tryParse(json['port_tcp'].toString()) ?? 1145,
      serverName: json['server_name'] as String? ?? 'TouchFish',
    );
  }
}


class TfCaptchaInfo {
  final String pic; // base64 encoded png
  final String stamp; // captcha identifier token

  const TfCaptchaInfo({required this.pic, required this.stamp});
}

/// TFV5 API CLIENT
class TfApiClient {
  static TfApiClient? _instance;
  static TfApiClient get instance => _instance ??= TfApiClient._();
  TfApiClient._();

  final _http = http.Client();

  RSAPublicKey? _cachedPubKey;
  String? _cachedBaseUrl;

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
      _cachedBaseUrl = 'http://${serverInfo.address}:$port';
      return _cachedBaseUrl!;
    }
    _cachedBaseUrl = 'http://${AppConstants.defaultServerAddress}:${AppConstants.defaultApiPort}';
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
    final response = await _http
        .get(Uri.parse('$baseUrl/get_rsa_pub'))
        .timeout(const Duration(seconds: 10));
    final pem = response.body;
    final pubKey = TfCrypto.parseRsaPublicKey(pem);
    _cachedPubKey = pubKey;
    _cachedBaseUrl = baseUrl;
    return pubKey;
  }

  Future<String?> secretPost(
    String path,
    Map<String, dynamic> body, {
    int? uid,
    String? password,
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final pubKey = await _getRsaPublicKey(baseUrl);

      final fullBody = Map<String, dynamic>.from(body);
      if (uid != null) fullBody['uid'] = uid;
      if (password != null) fullBody['password'] = password;

      final aesKey = TfCrypto.generateAesKey();
      final iv = TfCrypto.generateIv();
      final encryptedContent =
          TfCrypto.aesEncrypt(jsonEncode(fullBody), aesKey, iv);
      final encryptedAesKey = TfCrypto.rsaEncrypt(aesKey, pubKey);

      final requestBody = jsonEncode({
        'iv': base64.encode(iv),
        'key': base64.encode(encryptedAesKey),
        'content': base64.encode(encryptedContent),
      });

      final response = await _http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final responseData =
          jsonDecode(response.body) as Map<String, dynamic>;
      final responseIv =
          base64.decode(responseData['iv'] as String);
      final responseContent =
          base64.decode(responseData['content'] as String);

      return TfCrypto.aesDecrypt(responseContent, aesKey, responseIv);
    } catch (e) {
      talker.error('secretPost $path failed', e);
      return null;
    }
  }

  bool _parseBool(String? result) => result?.endsWith('True') ?? false;

  // server info

  Future<TfServerConfig?> fetchServerInfo() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _http
          .get(Uri.parse('$baseUrl/info'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return TfServerConfig.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      talker.error('fetchServerInfo failed', e);
      return null;
    }
  }

  // captcha

  Future<TfCaptchaInfo?> getCaptcha() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _http
          .get(Uri.parse('$baseUrl/auth/captcha'))
          .timeout(const Duration(seconds: 10));
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

  Future<UserProfile?> getUserByUid(int uid) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _http
          .get(Uri.parse('$baseUrl/auth/uid/$uid'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.isEmpty) return null;
      return UserProfile.fromServerJson(
          data, '$baseUrl/avatar/get_avatar/user/$uid');
    } catch (e) {
      talker.error('getUserByUid $uid failed', e);
      return null;
    }
  }

  Future<UserProfile?> getUserByUsername(String username) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _http
          .get(Uri.parse('$baseUrl/auth/username/$username'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.isEmpty) return null;
      final uid = data['uid'].toString();
      return UserProfile.fromServerJson(
          data, '$baseUrl/avatar/get_avatar/user/$uid');
    } catch (e) {
      talker.error('getUserByUsername $username failed', e);
      return null;
    }
  }

  Future<bool> login(int uid, String password) async {
    final result =
        await secretPost('/auth/login', {}, uid: uid, password: password);
    return _parseBool(result);
  }

  Future<bool> register(
    String username,
    String password, {
    String? email,
    String? captchaStamp,
    String? captchaCode,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'password': password,
    };
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
      int uid, String password, String newIntro) async {
    final result = await secretPost(
      '/auth/change_introduction',
      {'new_introduction': newIntro},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> changePassword(
      int uid, String password, String newPassword) async {
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
      int uid, String password, String picBase64) async {
    final result = await secretPost(
      '/avatar/upload_user_avatar',
      {'pic': picBase64},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  // forum

  Future<List<Forum>> getForumList() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await _http
          .get(Uri.parse('$baseUrl/forum/get_forum_list'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is! List) return [];
      return data
          .map((row) => Forum.fromServerRow(row as List<dynamic>))
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
          approvals.add(PendingForumApproval.fromQueueEntry(entry.key, rawValue));
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
      final response = await _http
          .get(Uri.parse('$baseUrl/forum/get_post_list/$fid'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is! List) return [];
      return data
          .map((row) =>
              ForumPost.fromServerRow(fid.toString(), row as List<dynamic>))
          .toList();
    } catch (e) {
      talker.error('getPostList $fid failed', e);
      return [];
    }
  }

  Future<bool> sendPost(
      int uid, String password, int fid, String title, String content) async {
    final result = await secretPost(
      '/forum/send_post',
      {'fid': fid, 'title': title, 'content': content},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> removePost(
      int uid, String password, int fid, int pid) async {
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
      final response = await _http
          .get(Uri.parse('$baseUrl/forum/get_all_comments/$fid/$pid'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is! Map) return [];
      final comments = <ForumComment>[];
      (data as Map<String, dynamic>).forEach((timestamp, value) {
        final items = value as List<dynamic>;
        final ms = (double.tryParse(timestamp) ?? 0) * 1000;
        comments.add(ForumComment(
          id: timestamp,
          postId: pid.toString(),
          authorUid: items[0].toString(),
          content: items[1] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
        ));
      });
      comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return comments;
    } catch (e) {
      talker.error('getAllComments $fid/$pid failed', e);
      return [];
    }
  }

  Future<bool> addComment(
      int uid, String password, int fid, int pid, String comment) async {
    final result = await secretPost(
      '/forum/comment',
      {'fid': fid, 'pid': pid, 'comment': comment},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> removeComment(
      int uid, String password, int fid, int pid, String sendTime) async {
    final result = await secretPost(
      '/forum/remove_comment',
      {'fid': fid, 'pid': pid, 'send_time': sendTime},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> createForum(
      int uid, String password, String forumName, String introduction) async {
    final result = await secretPost(
      '/forum/create_forum',
      {'forum_name': forumName, 'introduction': introduction},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }

  Future<bool> approveForum(
    int uid,
    String password,
    int queueId,
  ) async {
    final result = await secretPost(
      '/forum/approve_forum',
      {'qid': queueId},
      uid: uid,
      password: password,
    );
    return _parseBool(result);
  }
}
