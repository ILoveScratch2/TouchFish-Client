import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_service.dart';
import '../models/user_profile.dart';
import '../utils/talker.dart';
import 'api/tf_api_client.dart';
import 'local_message_store.dart';

enum SavedSessionRestoreStatus { idle, restoring, succeeded, failed }

/// 已保存会话恢复失败的原因，用于 UI 区分提示。
enum RestoreFailureReason { none, tokenExpired, credentials, network }

class _AuthSessionNotifier extends ChangeNotifier {
  void changed() => notifyListeners();
}

class AuthState extends ChangeNotifier {
  static AuthState? _instance;
  static AuthState get instance => _instance ??= AuthState._();
  AuthState._();

  static const _kTokenKey = 'auth_token';
  static const _kTokenExpiresAtKey = 'auth_token_expires_at';

  UserProfile? _currentUser;
  int? _uid;
  String? _password;
  String? _token;
  int? _tokenExpiresAt;
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

  UserProfile? get currentUser => _currentUser;
  int? get uid => _uid;

  /// JWT 模式下若内存密码不可用（token 恢复会话），返回空串占位
  String? get password =>
      _password ?? (isJwtMode ? '' : null);
  String? get token => _token;
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
    _rememberedPassword = prefs.getString('auth_password');
    _token = prefs.getString(_kTokenKey);
    _tokenExpiresAt = prefs.getInt(_kTokenExpiresAtKey);
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

  Future<bool> restoreSavedSession() async {
    if (!hasStoredCredentials) return false;

    _savedSessionRestoreStatus = SavedSessionRestoreStatus.restoring;
    _notifySessionChanged();

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
        final valid = await TfApiClient.instance.validateToken();
        if (valid == true && profile != null) {
          final baseUrl = await TfApiClient.instance.getBaseUrl();
          LocalMessageStore.instance.configureScope(baseUrl, savedUid);
          _uid = savedUid;
          _password = null;
          _currentUser = profile;
          _authMode = TfAuthMode.jwt;
          _rememberedUsername ??= profile.username;
          _savedSessionRestoreStatus = SavedSessionRestoreStatus.succeeded;
          _restoreFailureReason = RestoreFailureReason.none;
          _notifySessionChanged();
          return true;
        }
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
        // token 被服务器明确拒绝（过期/吊销）
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
          final baseUrl = await TfApiClient.instance.getBaseUrl();
          LocalMessageStore.instance.configureScope(baseUrl, savedUid);
          _uid = savedUid;
          _password = savedPassword;
          _token = null;
          _tokenExpiresAt = null;
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

      _degradedToLegacy = result.degraded;
      if (result.mode == TfAuthMode.jwt && result.token != null) {
        _token = result.token;
        _tokenExpiresAt = result.expiresAt;
        _authMode = TfAuthMode.jwt;
      } else {
        _token = null;
        _tokenExpiresAt = null;
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

      _notifySessionChanged();
      return null;
    } catch (e) {
      talker.error('AuthState.login failed', e);
      return 'networkError';
    }
  }

  /// 静默重登（JWT 模式，运行时 token 失效时使用内存密码换新 token）。
  /// 无法自愈（无内存密码 / 重登被拒）时触发会话过期强制登出。
  Future<bool> relogin() async {
    if (_uid == null) return false;
    if (_authMode != TfAuthMode.jwt) return false;
    if (_password == null) {
      // JWT 恢复会话：token 已失效且无密码可用，无法自愈
      unawaited(_handleSessionExpired());
      return false;
    }
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
      final result = await TfApiClient.instance.login(
        _uid!,
        _password!,
        legacyMode: false,
      );
      if (result.error != null || result.token == null) return false;
      _token = result.token;
      _tokenExpiresAt = result.expiresAt;
      _authMode = TfAuthMode.jwt;
      _degradedToLegacy = false;
      TfApiClient.instance.setAuthContext(token: _token, legacyMode: false);
      final prefs = await SharedPreferences.getInstance();
      await _persistCredentials(
        prefs,
        uid: _uid!,
        username: _rememberedUsername ?? _currentUser?.username ?? '',
        password: null,
      );
      return true;
    } catch (e) {
      talker.error('AuthState.relogin failed', e);
      return false;
    }
  }

  Future<void> logout() async {
    // 先快照当前 token 并请求服务器吊销
    final currentToken = isJwtMode ? _token : null;
    if (currentToken != null) {
      unawaited(TfApiClient.instance.logoutCurrentToken(currentToken));
    }
    _uid = null;
    _password = null;
    _token = null;
    _tokenExpiresAt = null;
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
    final prefs = await SharedPreferences.getInstance();
    await _clearStorage(prefs);
  }

  Future<void> refreshProfile() async {
    if (_uid == null) return;
    try {
      final profile = await TfApiClient.instance.getUserByUid(
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
    await prefs.remove('auth_uid');
    await prefs.remove('auth_username');
    await prefs.remove('auth_password');
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kTokenExpiresAtKey);
  }

  Future<void> _persistCredentials(
    SharedPreferences prefs, {
    required int uid,
    required String username,
    required String? password,
  }) async {
    await prefs.setInt('auth_uid', uid);
    await prefs.setString('auth_username', username);
    if (_authMode == TfAuthMode.jwt && _token != null) {
      await prefs.setString(_kTokenKey, _token!);
      if (_tokenExpiresAt != null) {
        await prefs.setInt(_kTokenExpiresAtKey, _tokenExpiresAt!);
      } else {
        await prefs.remove(_kTokenExpiresAtKey);
      }
      await prefs.remove('auth_password');
    } else {
      if (password != null) {
        await prefs.setString('auth_password', password);
      } else {
        await prefs.remove('auth_password');
      }
      await prefs.remove(_kTokenKey);
      await prefs.remove(_kTokenExpiresAtKey);
    }
  }
}
