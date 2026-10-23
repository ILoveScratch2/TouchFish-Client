import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_service.dart';
import '../models/user_profile.dart';
import '../utils/talker.dart';
import 'api/tf_api_client.dart';
import 'local_message_store.dart';
import 'multi_instance_guard.dart';
import 'secure_credentials.dart';
import 'token_refresh_manager.dart';

enum SavedSessionRestoreStatus { idle, restoring, succeeded, failed }

/// 已保存会话恢复失败的原因，用于 UI 区分提示。
enum RestoreFailureReason { none, tokenExpired, credentials, network, duplicateSession }

class _AuthSessionNotifier extends ChangeNotifier {
  void changed() => notifyListeners();
}

class AuthState extends ChangeNotifier {
  static AuthState? _instance;
  static AuthState get instance => _instance ??= AuthState._();
  AuthState._();

  static const _kTokenKey = 'auth_token';
  static const _kTokenExpiresAtKey = 'auth_token_expires_at';
  static const _kRefreshTokenKey = 'auth_refresh_token';
  static const _kRefreshExpiresAtKey = 'auth_refresh_expires_at';
  static const _kPasswordKey = 'auth_password';

  UserProfile? _currentUser;
  int? _uid;
  String? _password;
  String? _token;
  int? _tokenExpiresAt;
  String? _refreshToken;
  int? _refreshExpiresAt;
  TfAuthMode _authMode = TfAuthMode.jwt;
  bool _degradedToLegacy = false;
  String? _deprecationNotice;
  bool _deprecationNoticeShown = false;
  Future<bool>? _reloginFuture;
  int? _rememberedUid;
  String? _rememberedUsername;
  String? _rememberedPassword;
  SavedSessionRestoreStatus _savedSessionRestoreStatus =
      SavedSessionRestoreStatus.idle;
  RestoreFailureReason _restoreFailureReason = RestoreFailureReason.none;
  bool _sessionExpiredNotice = false;
  int _avatarVersion = 0;
  final _sessionNotifier = _AuthSessionNotifier();
  Future<bool>? _refreshFuture;

  UserProfile? get currentUser => _currentUser;
  int? get uid => _uid;

  /// 已保存会话的 uid（`init()` 就会填充）。
  ///
  /// 通知栏快捷回复这类后台 isolate 不会执行 `main()`，只调 `init()` 时
  /// [uid] 仍是 null，必须用它兜底。
  int? get rememberedUid => _rememberedUid;

  /// JWT 模式下若内存密码不可用（token 恢复会话），返回空串占位
  String? get password =>
      _password ?? (isJwtMode ? '' : null);
  String? get token => _token;
  int? get tokenExpiresAt => _tokenExpiresAt;
  String? get refreshToken => _refreshToken;
  TfAuthMode get authMode => _authMode;
  bool get isJwtMode => _authMode == TfAuthMode.jwt && _token != null;
  bool get degradedToLegacy => _degradedToLegacy;
  String? get deprecationNotice => _deprecationNotice;
  String? get rememberedUsername => _rememberedUsername;
  String? get rememberedPassword => _rememberedPassword;
  bool get hasStoredCredentials =>
      _rememberedUid != null && (_rememberedPassword != null || _token != null);
  SavedSessionRestoreStatus get savedSessionRestoreStatus =>
      _savedSessionRestoreStatus;

  /// 已保存会话恢复失败的原因
  RestoreFailureReason get restoreFailureReason => _restoreFailureReason;

  /// 运行时 token 失效且无法 mastur**** 的一次性提示标志。
  bool get sessionExpiredNotice => _sessionExpiredNotice;
  bool get isLoggedIn => _currentUser != null && _uid != null;
  bool get isBanned => _currentUser?.stat == 'banned';
  Listenable get sessionListenable => _sessionNotifier;

  void _notifySessionChanged() {
    _sessionNotifier.changed();
    notifyListeners();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberedUid = prefs.getInt('auth_uid');
    _rememberedUsername = prefs.getString('auth_username');
    _tokenExpiresAt = prefs.getInt(_kTokenExpiresAtKey);
    _refreshExpiresAt = prefs.getInt(_kRefreshExpiresAtKey);
    await _loadSecrets(prefs);
    if (_rememberedUid != null && _token == null && _rememberedPassword == null) {
      // 凭据只在安全存储里时，启动时一次探测失败（Keychain 未解锁、插件刚好
      // 还没就绪）会让人被静默登出。这里强制重探一次并重读。
      await _reloadSecretsFromSecure();
    }
    _authMode = _token != null ? TfAuthMode.jwt : TfAuthMode.legacy;
    TfApiClient.instance.setAuthContext(
      token: _token,
      legacyMode: !isJwtMode,
    );
    TfApiClient.instance.setTokenExpiredHandler(relogin);
    TfApiClient.instance.setAuthNoteHandler(_handleAuthNote);
    _savedSessionRestoreStatus = SavedSessionRestoreStatus.idle;
    _restoreFailureReason = RestoreFailureReason.none;
  }

  /// 强制重探安全存储并重读凭据（启动时探测失败 / 用户点"重试"的唯一补救路径）。
  Future<void> _reloadSecretsFromSecure() async {
    try {
      if (!await SecureCredentials.instance.probe(force: true)) return;
      final prefs = await SharedPreferences.getInstance();
      await _loadSecrets(prefs);
      _authMode = _token != null ? TfAuthMode.jwt : TfAuthMode.legacy;
      TfApiClient.instance.setAuthContext(
        token: _token,
        legacyMode: _authMode == TfAuthMode.legacy,
      );
    } catch (e) {
      talker.warning('AuthState: reloading secure credentials failed: $e');
    }
  }

  Future<void> _loadSecrets(SharedPreferences prefs) async {
    final secure = SecureCredentials.instance;
    const keys = [_kTokenKey, _kRefreshTokenKey, _kPasswordKey];
    String? nonEmpty(String? value) =>
        (value == null || value.isEmpty) ? null : value;

    if (await secure.probe()) {
      final stored = await secure.readAll(keys);
      final plaintext = {
        _kTokenKey: nonEmpty(prefs.getString(_kTokenKey)),
        _kRefreshTokenKey: nonEmpty(prefs.getString(_kRefreshTokenKey)),
        _kPasswordKey: nonEmpty(prefs.getString(_kPasswordKey)),
      };
      _token = plaintext[_kTokenKey] ?? nonEmpty(stored[_kTokenKey]);
      _refreshToken =
          plaintext[_kRefreshTokenKey] ?? nonEmpty(stored[_kRefreshTokenKey]);
      _rememberedPassword =
          plaintext[_kPasswordKey] ?? nonEmpty(stored[_kPasswordKey]);

      for (final key in keys) {
        final value = plaintext[key];
        if (value == null) {
          // 明文里没有值（或只有一个空的占位）：清理掉空副本即可
          if (prefs.containsKey(key)) await prefs.remove(key);
          continue;
        }
        if (stored[key] == value) {
          // 安全存储里已经是同一个值：明文副本可以删
          await prefs.remove(key);
          continue;
        }
        final migrated = await secure.write(key, value);
        if (migrated) {
          await prefs.remove(key);
        } else {
          talker.warning(
            'AuthState: failed to move $key into secure storage, '
            'keeping the SharedPreferences copy for the next start',
          );
        }
      }
      return;
    }
    // 平台不支持安全存储：保持旧行为（token 在 prefs），并明确记录一次
    _token = prefs.getString(_kTokenKey);
    _refreshToken = prefs.getString(_kRefreshTokenKey);
    _rememberedPassword = prefs.getString(_kPasswordKey);
    if (_token != null || _rememberedPassword != null) {
      talker.warning(
        'AuthState: secure storage unavailable, credentials stay in '
        'SharedPreferences on this platform',
      );
    }
  }

  Future<bool> restoreSavedSession() async {
    if (_rememberedUid == null) return false;

    _savedSessionRestoreStatus = SavedSessionRestoreStatus.restoring;
    _notifySessionChanged();

    if (!hasStoredCredentials) {
      // 启动时安全存储探测失败过：这里（以及用户点「重试」时）强制重探一次。
      await _reloadSecretsFromSecure();
    }
    if (!hasStoredCredentials) {
      // 凭据确实读不出来：明确报「凭据不可用」并保留重试入口，
      // 不能静默停在登录页（用户会以为账号被登出了）。
      talker.warning(
        'AuthState.restoreSavedSession: no readable credentials for uid=$_rememberedUid',
      );
      _restoreFailureReason = RestoreFailureReason.credentials;
      _savedSessionRestoreStatus = SavedSessionRestoreStatus.failed;
      _notifySessionChanged();
      return false;
    }

    final savedUid = _rememberedUid!;
    final legacyForced = SettingsService.instance.getValue<bool>(
      'legacyAuthMode',
      false,
    );

    try {
      final profile = await TfApiClient.instance.getUserByUid(
        savedUid,
        avatarVersion: _avatarVersion,
      );

      if (_token != null && !legacyForced) {
        // JWT 模式：用 token 恢复会话
        TfApiClient.instance.setAuthContext(token: _token, legacyMode: false);
        var valid = await TfApiClient.instance.validateToken();
        if (valid == null) {
          // 网络/服务器异常：保留凭据
          talker.warning(
            'AuthState.restoreSavedSession: network failure during JWT validation.',
          );
          _restoreFailureReason = RestoreFailureReason.network;
          _savedSessionRestoreStatus = SavedSessionRestoreStatus.failed;
          _notifySessionChanged();
          return false;
        }

        // access token 被拒绝时，尝试用 refresh token 轮换恢复。
        // 走 refreshAccessToken 单飞：refresh token 用一次就轮换，
        // 分散的刷新路径（这里 + TokenRefreshManager）必然有一方失败。
        // 此时 _uid 还没赋值，所以显式把目标 uid 传进去。
        if (valid == false && _refreshToken != null && _refreshToken!.isNotEmpty) {
          _rememberedUsername ??= profile?.username;
          if (await refreshAccessToken(uid: savedUid)) {
            valid = true;
          }
        }

        if (valid == true && profile != null) {
          // 多开互斥：同一服务器同一账号已被其它实例登录时，不在此实例恢复。
          final acquired = await MultiInstanceGuard.instance.acquire(
            uid: savedUid,
            username: profile.username,
          );
          if (!acquired) {
            talker.info(
              'AuthState.restoreSavedSession: (server, uid=$savedUid) already held by another instance.',
            );
            _restoreFailureReason = RestoreFailureReason.duplicateSession;
            _savedSessionRestoreStatus = SavedSessionRestoreStatus.failed;
            _notifySessionChanged();
            return false;
          }
          final baseUrl = await TfApiClient.instance.getBaseUrl();
          LocalMessageStore.instance.configureScope(baseUrl, savedUid);
          _uid = savedUid;
          _password = null;
          _currentUser = profile;
          _authMode = TfAuthMode.jwt;
          _rememberedUsername ??= profile.username;
          _savedSessionRestoreStatus = SavedSessionRestoreStatus.succeeded;
          _restoreFailureReason = RestoreFailureReason.none;
          // 启动 token 自动刷新
          TokenRefreshManager.instance.startAutoRefresh(_tokenExpiresAt);
          _notifySessionChanged();
          // 恢复成功后补一次本人资料刷新（含被隐藏的邮箱与 public_email 开关）
          unawaited(refreshProfile());
          return true;
        }
        // token 被服务器明确拒绝（过期/吊销）且无法 refresh
        _restoreFailureReason = RestoreFailureReason.tokenExpired;
        talker.warning(
          'AuthState.restoreSavedSession: saved JWT was rejected by the server.',
        );
      } else if (_rememberedPassword != null) {
        // 旧版（兼容）模式：密码重login
        final savedPassword = _rememberedPassword!;
        final result = await TfApiClient.instance.login(
          savedUid,
          savedPassword,
          legacyMode: true,
        );
        if (result.error == null && profile != null) {
          // 多开互斥：同一服务器同一账号已被其它实例登录时，不在此实例恢复。
          final acquired = await MultiInstanceGuard.instance.acquire(
            uid: savedUid,
            username: profile.username,
          );
          if (!acquired) {
            talker.info(
              'AuthState.restoreSavedSession: (server, uid=$savedUid) already held by another instance.',
            );
            _restoreFailureReason = RestoreFailureReason.duplicateSession;
            _savedSessionRestoreStatus = SavedSessionRestoreStatus.failed;
            _notifySessionChanged();
            return false;
          }
          final baseUrl = await TfApiClient.instance.getBaseUrl();
          LocalMessageStore.instance.configureScope(baseUrl, savedUid);
          _uid = savedUid;
          _password = savedPassword;
          _token = null;
          _tokenExpiresAt = null;
          _refreshToken = null;
          _refreshExpiresAt = null;
          _currentUser = profile;
          _authMode = TfAuthMode.legacy;
          _rememberedUsername ??= profile.username;
          TfApiClient.instance.setAuthContext(
            token: null,
            legacyMode: true,
          );
          _savedSessionRestoreStatus = SavedSessionRestoreStatus.succeeded;
          _restoreFailureReason = RestoreFailureReason.none;

          final prefs = await SharedPreferences.getInstance();
          await _persistCredentials(
            prefs,
            uid: savedUid,
            username: _rememberedUsername ?? profile.username,
            password: savedPassword,
          );

          _notifySessionChanged();
          // 恢复成功后补一次本人资料刷新（含被隐藏的邮箱与 public_email 开关）
          unawaited(refreshProfile());
          return true;
        }
        _restoreFailureReason = RestoreFailureReason.credentials;
        talker.warning(
          'AuthState.restoreSavedSession: saved session was rejected by the server.',
        );
      }
    } catch (e, stackTrace) {
      talker.error('AuthState.restoreSavedSession failed', e, stackTrace);
      // 网络/服务器异常：保留凭据，由 UI 提供重试
      _restoreFailureReason = RestoreFailureReason.network;
      _savedSessionRestoreStatus = SavedSessionRestoreStatus.failed;
      _notifySessionChanged();
      return false;
    }

    _uid = null;
    _password = null;
    _token = null;
    _tokenExpiresAt = null;
    _refreshToken = null;
    _refreshExpiresAt = null;
    _currentUser = null;
    TfApiClient.instance.setAuthContext(token: null, legacyMode: true);
    _savedSessionRestoreStatus = SavedSessionRestoreStatus.failed;
    _notifySessionChanged();
    return false;
  }

  void clearSavedSessionRestoreFailure() {
    if (_savedSessionRestoreStatus != SavedSessionRestoreStatus.failed) {
      return;
    }

    _savedSessionRestoreStatus = SavedSessionRestoreStatus.idle;
    _restoreFailureReason = RestoreFailureReason.none;
    _notifySessionChanged();
  }

  /// 消费会话过期提示（UI 展示后调用）。
  void clearSessionExpiredNotice() {
    if (!_sessionExpiredNotice) return;
    _sessionExpiredNotice = false;
    _notifySessionChanged();
  }

  Future<String?> login(String username, String password) async {
    try {
      final profile = await TfApiClient.instance.getUserByUsername(username);
      if (profile == null) {
        return 'userNotFound';
      }

      final uid = int.tryParse(profile.uid);
      if (uid == null) return 'serverError';

      final legacyForced = SettingsService.instance.getValue<bool>(
        'legacyAuthMode',
        false,
      );
      final result = await TfApiClient.instance.login(
        uid,
        password,
        legacyMode: legacyForced,
      );

      if (result.error != null) {
        return switch (result.error!) {
          'authFailed' => 'invalidCredentials',
          'tokenLimitReached' => 'sessionLimitReached',
          _ => 'networkError',
        };
      }

      // 多开互斥：先占位，成功后才会在本实例建立会话；被占则拒绝并吊销刚签发的 token。
      final acquired = await MultiInstanceGuard.instance.acquire(
        uid: uid,
        username: profile.username,
      );
      if (!acquired) {
        if (result.mode == TfAuthMode.jwt && result.token != null) {
          unawaited(TfApiClient.instance.logoutCurrentToken(result.token!));
        }
        talker.info(
          'AuthState.login: (server, uid=$uid) already held by another instance; rejecting.',
        );
        return 'duplicateLogin';
      }

      _degradedToLegacy = result.degraded;
      if (result.mode == TfAuthMode.jwt && result.token != null) {
        _token = result.token;
        _tokenExpiresAt = result.expiresAt;
        _refreshToken = result.refreshToken;
        _refreshExpiresAt = result.refreshExpiresAt;
        _authMode = TfAuthMode.jwt;
      } else {
        _token = null;
        _tokenExpiresAt = null;
        _refreshToken = null;
        _refreshExpiresAt = null;
        _authMode = TfAuthMode.legacy;
      }
      _password = password;
      TfApiClient.instance.setAuthContext(
        token: _token,
        legacyMode: _authMode == TfAuthMode.legacy,
      );

      final baseUrl = await TfApiClient.instance.getBaseUrl();
      LocalMessageStore.instance.configureScope(baseUrl, uid);
      _uid = uid;
      _currentUser = profile;
      _rememberedUid = uid;
      _rememberedUsername = profile.username;
      _rememberedPassword =
          _authMode == TfAuthMode.legacy ? password : null;
      _savedSessionRestoreStatus = SavedSessionRestoreStatus.idle;
      _restoreFailureReason = RestoreFailureReason.none;

      final prefs = await SharedPreferences.getInstance();
      await _persistCredentials(
        prefs,
        uid: uid,
        username: profile.username,
        password: _rememberedPassword,
      );

      // 启动 token 自动刷新（JWT 模式）
      if (_authMode == TfAuthMode.jwt) {
        TokenRefreshManager.instance.startAutoRefresh(_tokenExpiresAt);
      }

      _notifySessionChanged();
      return null;
    } catch (e) {
      talker.error('AuthState.login failed', e);
      return 'networkError';
    }
  }

  /// 用外部登录平台（TouchFish Auth）的凭据换取本服务器会话。
  ///
  /// 与 [login] 走同一套收口逻辑（多开互斥 / 本地消息库分区 / token 自动刷新），
  /// 否则会出现"已登录但 WS 与本地库未配置 scope"的半登录态。
  ///
  /// 返回 null 表示成功；否则返回错误标识，供调用方映射文案。
  Future<String?> loginWithExternalSession(String externalToken) async {
    // 回滚要覆盖整个函数（含 catch 里的异常），所以状态放在 try 之外。
    final previousToken = _token;
    final previousMode = _authMode;
    final previousDegraded = _degradedToLegacy;
    String? issuedToken;
    var committed = false;

    void rollback() {
      if (committed) return;
      TfApiClient.instance.setAuthContext(
        token: previousToken,
        legacyMode: previousMode == TfAuthMode.legacy,
      );
      // 同步切回内存登录态，否则「HTTP 层旧 token / 内存新 token」半登录残留。
      _token = previousToken;
      _authMode = previousMode;
      _degradedToLegacy = previousDegraded;
      if (issuedToken != null) {
        unawaited(TfApiClient.instance.logoutCurrentToken(issuedToken));
      }
    }

    try {
      final result = await TfApiClient.instance.loginWithExternalToken(
        externalToken,
      );
      if (result.error != null) {
        return switch (result.error!) {
          'externalNotLinked' => 'externalNotLinked',
          'externalTokenInvalid' => 'externalTokenInvalid',
          'userBanned' => 'userBanned',
          'tokenLimitReached' => 'sessionLimitReached',
          _ => 'networkError',
        };
      }
      if (result.mode != TfAuthMode.jwt || result.token == null) {
        return 'serverError';
      }
      issuedToken = result.token;

      // 只把 token 交给 HTTP 层，供 getSelfProfile 使用；
      // 认证状态本身等校验通过后再写，避免"半登录"残留。
      TfApiClient.instance.setAuthContext(token: result.token, legacyMode: false);

      final profile = await TfApiClient.instance.getSelfProfile();
      if (profile == null) {
        rollback();
        return 'serverError';
      }
      final uid = int.tryParse(profile.uid);
      if (uid == null) {
        rollback();
        return 'serverError';
      }

      final acquired = await MultiInstanceGuard.instance.acquire(
        uid: uid,
        username: profile.username,
      );
      if (!acquired) {
        rollback();
        return 'duplicateLogin';
      }

      // 校验全部通过，开始落状态。committed 暂不置 true——
      // 落盘/通知等副作用若失败，catch 里的 rollback() 需要把内存与 HTTP 层
      // 一并切回原状；只有所有副作用都完成后才标记不可回滚。
      _token = result.token;
      _tokenExpiresAt = result.expiresAt;
      _refreshToken = result.refreshToken;
      _refreshExpiresAt = result.refreshExpiresAt;
      _authMode = TfAuthMode.jwt;
      _degradedToLegacy = false;
      TfApiClient.instance.setAuthContext(token: _token, legacyMode: false);

      final baseUrl = await TfApiClient.instance.getBaseUrl();
      LocalMessageStore.instance.configureScope(baseUrl, uid);
      _uid = uid;
      _currentUser = profile;
      _rememberedUid = uid;
      _rememberedUsername = profile.username;
      // 外部登录不掌握服务器密码，静默重登只能依赖 refresh token。
      _password = null;
      _rememberedPassword = null;
      _savedSessionRestoreStatus = SavedSessionRestoreStatus.idle;
      _restoreFailureReason = RestoreFailureReason.none;

      final prefs = await SharedPreferences.getInstance();
      await _persistCredentials(
        prefs,
        uid: uid,
        username: profile.username,
        password: null,
      );

      TokenRefreshManager.instance.startAutoRefresh(_tokenExpiresAt);
      _notifySessionChanged();
      // 所有副作用完成，此后再失败也不回滚（会话在服务端已成立、UI 已通知）。
      committed = true;
      return null;
    } catch (e) {
      // 落盘/SharedPreferences 等失败时也要把 HTTP 层切回原状态，
      // 否则后续请求会带着一个"没有对应会话"的 token。
      rollback();
      talker.error('AuthState.loginWithExternalSession failed', e);
      return 'networkError';
    }
  }

  /// 静默重登（JWT 模式，运行时 token 失效时优先用 refresh token 换新 token，
  /// 无 refresh token 时才回退到内存密码重新登录）。
  /// 无法自愈时触发会话过期强制登出。
  Future<bool> relogin() async {
    if (_uid == null) return false;
    if (_authMode != TfAuthMode.jwt) return false;
    final pending = _reloginFuture;
    if (pending != null) return pending;
    final future = _doRelogin();
    _reloginFuture = future;
    try {
      final ok = await future;
      if (!ok) unawaited(_handleSessionExpired());
      return ok;
    } finally {
      _reloginFuture = null;
    }
  }

  /// 会话失效强制登出：置位一次性提示后清空会话
  Future<void> _handleSessionExpired() async {
    if (_sessionExpiredNotice) return;
    _sessionExpiredNotice = true;
    await logout();
  }

  Future<bool> _doRelogin() async {
    try {
      // 优先用 refresh token 轮换（无需密码）；单飞，避免与定时刷新重复轮换
      if (await refreshAccessToken()) {
        TokenRefreshManager.instance.startAutoRefresh(_tokenExpiresAt);
        return true;
      }

      // 回退：用内存密码重新登录（仅当仍持有密码时）
      if (_password == null) return false;
      final result = await TfApiClient.instance.login(
        _uid!,
        _password!,
        legacyMode: false,
      );
      if (result.error != null || result.token == null) {
        return false;
      }
      if (!await _applyTokenResult(result)) return false;
      // 重新启动 token 自动刷新
      TokenRefreshManager.instance.startAutoRefresh(_tokenExpiresAt);
      return true;
    } catch (e) {
      talker.error('AuthState.relogin failed', e);
      return false;
    }
  }

  /// 用当前 refresh token 换一次新 token
  ///
  /// 服务端的 refresh token 是「用一次就轮换」的 compare-and-swap：同一条 refresh
  /// token 第二次使用必然失败。因此所有刷新路径都必须经过这里，不能各自调用
  /// `TfApiClient.refreshToken`。
  /// [uid] 只在 restoreSavedSession 里用：那时 _uid 还没有赋值。
  Future<bool> refreshAccessToken({int? uid}) {
    final targetUid = uid ?? _uid;
    if (targetUid == null || _authMode != TfAuthMode.jwt) {
      return Future.value(false);
    }
    final pending = _refreshFuture;
    if (pending != null) return pending;
    // 存进字段的必须就是返回给调用方的那个 future：否则「已完成但 whenComplete
    // 还没跑」的窗口里，新调用会拿到上一次的旧结果而不真正刷新。
    late final Future<bool> future;
    future = _refreshAccessTokenOnce(targetUid).whenComplete(() {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    });
    _refreshFuture = future;
    return future;
  }

  Future<bool> _refreshAccessTokenOnce(int uid) async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_refreshExpiresAt != null && _refreshExpiresAt! <= now) return false;
    try {
      final result = await TfApiClient.instance.refreshToken(refreshToken);
      if (result == null || result.error != null || result.token == null) {
        return false;
      }
      return await _applyTokenResult(result, uid: uid);
    } catch (e) {
      talker.error('AuthState.refreshAccessToken failed', e);
      return false;
    }
  }

  /// 把一次成功的登录/刷新结果写回内存与本地存储。
  Future<bool> _applyTokenResult(TfLoginResult result, {int? uid}) async {
    final token = result.token;
    final targetUid = uid ?? _uid;
    if (token == null || targetUid == null) return false;
    _token = token;
    _tokenExpiresAt = result.expiresAt;
    _refreshToken = result.refreshToken ?? _refreshToken;
    _refreshExpiresAt = result.refreshExpiresAt ?? _refreshExpiresAt;
    _authMode = TfAuthMode.jwt;
    _degradedToLegacy = false;
    TfApiClient.instance.setAuthContext(token: _token, legacyMode: false);
    final prefs = await SharedPreferences.getInstance();
    await _persistCredentials(
      prefs,
      uid: targetUid,
      username: _rememberedUsername ?? _currentUser?.username ?? '',
      password: null,
    );
    return true;
  }

  Future<void> logout() async {
    // 停止 token 自动刷新
    TokenRefreshManager.instance.stop();
    // 先快照当前 token 并请求服务器吊销
    final currentToken = isJwtMode ? _token : null;
    if (currentToken != null) {
      unawaited(TfApiClient.instance.logoutCurrentToken(currentToken));
    }
    _uid = null;
    _password = null;
    _token = null;
    _tokenExpiresAt = null;
    _refreshToken = null;
    _refreshExpiresAt = null;
    _currentUser = null;
    _authMode = TfAuthMode.jwt;
    _degradedToLegacy = false;
    _deprecationNotice = null;
    _deprecationNoticeShown = false;
    _rememberedUid = null;
    _rememberedUsername = null;
    _rememberedPassword = null;
    _savedSessionRestoreStatus = SavedSessionRestoreStatus.idle;
    _restoreFailureReason = RestoreFailureReason.none;
    TfApiClient.instance.setAuthContext(token: null, legacyMode: true);
    _notifySessionChanged();
    LocalMessageStore.instance.clearScope();
    // 释放多开互斥占位（fail-open：非桌面/未开启时 no-op）
    await MultiInstanceGuard.instance.release();
    final prefs = await SharedPreferences.getInstance();
    await _clearStorage(prefs);
  }

  Future<void> refreshProfile() async {
    if (_uid == null) return;
    try {
      // 本人资料优先走鉴权端点：能看到被隐藏的真实邮箱与 public_email 开关；
      // 旧服务器没有该端点时回退到公开查询（行为与以前一致）。
      final profile =
          await TfApiClient.instance.getSelfProfile(
            uid: _uid,
            password: _password,
            avatarVersion: _avatarVersion,
          ) ??
          await TfApiClient.instance.getUserByUid(
            _uid!,
            avatarVersion: _avatarVersion,
          );
      if (profile != null) {
        _currentUser = profile;
        notifyListeners();
      }
    } catch (e) {
      talker.error('AuthState.refreshProfile failed', e);
    }
  }

  void bumpAvatarVersion() {
    _avatarVersion++;
  }

  void _handleAuthNote(String note) {
    _deprecationNotice = note;
    if (!_deprecationNoticeShown) {
      _deprecationNoticeShown = true;
      _notifySessionChanged();
    }
  }

  Future<void> _clearStorage(SharedPreferences prefs) async {
    for (final key in const [_kTokenKey, _kRefreshTokenKey, _kPasswordKey]) {
      await SecureCredentials.instance.delete(key);
    }
    await prefs.remove('auth_uid');
    await prefs.remove('auth_username');
    await prefs.remove('auth_password');
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kTokenExpiresAtKey);
    await prefs.remove(_kRefreshTokenKey);
    await prefs.remove(_kRefreshExpiresAtKey);
  }

  /// FORK YOU localStorage
  Future<bool> _persistString(
    SharedPreferences prefs,
    String key,
    String value,
  ) async {
    try {
      await prefs.setString(key, value);
      return true;
    } catch (e) {
      talker.warning('AuthState: 写入 $key 失败，清理本地消息缓存后重试（$e）');
    }
    try {
      await LocalMessageStore.instance.emergencyTrimForQuota();
      await prefs.setString(key, value);
      return true;
    } catch (e) {
      talker.error('AuthState: 写入 $key 仍然失败 $e');
      return false;
    }
  }

  Future<void> _persistCredentials(
    SharedPreferences prefs, {
    required int uid,
    required String username,
    required String? password,
  }) async {
    await prefs.setInt('auth_uid', uid);
    await prefs.setString('auth_username', username);
    final hasSecure = await SecureCredentials.instance.probe();
    if (_authMode == TfAuthMode.jwt && _token != null) {
      await _writeSecret(prefs, hasSecure, _kTokenKey, _token!);
      if (_tokenExpiresAt != null) {
        await prefs.setInt(_kTokenExpiresAtKey, _tokenExpiresAt!);
      } else {
        await prefs.remove(_kTokenExpiresAtKey);
      }
      if (_refreshToken != null && _refreshToken!.isNotEmpty) {
        await _writeSecret(prefs, hasSecure, _kRefreshTokenKey, _refreshToken!);
        if (_refreshExpiresAt != null) {
          await prefs.setInt(_kRefreshExpiresAtKey, _refreshExpiresAt!);
        } else {
          await prefs.remove(_kRefreshExpiresAtKey);
        }
      } else {
        await _deleteSecret(prefs, hasSecure, _kRefreshTokenKey);
        await prefs.remove(_kRefreshExpiresAtKey);
      }
      await _deleteSecret(prefs, hasSecure, _kPasswordKey);
    } else {
      if (password != null) {
        await _writeSecret(prefs, hasSecure, _kPasswordKey, password);
      } else {
        await _deleteSecret(prefs, hasSecure, _kPasswordKey);
      }
      await _deleteSecret(prefs, hasSecure, _kTokenKey);
      await prefs.remove(_kTokenExpiresAtKey);
      await _deleteSecret(prefs, hasSecure, _kRefreshTokenKey);
      await prefs.remove(_kRefreshExpiresAtKey);
    }
  }

  /// 敏感字段：安全存储可用就写安全存储，并在 prefs 里删掉同名键。
  Future<void> _writeSecret(
    SharedPreferences prefs,
    bool hasSecure,
    String key,
    String value,
  ) async {
    if (hasSecure && await SecureCredentials.instance.write(key, value)) {
      await prefs.remove(key);
      return;
    }
    // 回退到明文必须留下痕迹：probe 成功但写失败（Keychain 锁住、磁盘满）
    // 时用户会以为凭据在加密存储里，实际在 SharedPreferences。
    talker.warning(
      'AuthState: $key stored in SharedPreferences ('
      '${hasSecure ? 'secure storage write failed' : 'secure storage unavailable'})',
    );
    await _persistString(prefs, key, value);
  }

  Future<void> _deleteSecret(
    SharedPreferences prefs,
    bool hasSecure,
    String key,
  ) async {
    if (hasSecure) await SecureCredentials.instance.delete(key);
    await prefs.remove(key);
  }
}
