import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../utils/talker.dart';
import 'api/tf_api_client.dart';

enum SavedSessionRestoreStatus { idle, restoring, succeeded, failed }

class AuthState extends ChangeNotifier {
  static AuthState? _instance;
  static AuthState get instance => _instance ??= AuthState._();
  AuthState._();

  UserProfile? _currentUser;
  int? _uid;
  String? _password;
  int? _rememberedUid;
  String? _rememberedUsername;
  String? _rememberedPassword;
  SavedSessionRestoreStatus _savedSessionRestoreStatus =
      SavedSessionRestoreStatus.idle;
  int _avatarVersion = 0;

  UserProfile? get currentUser => _currentUser;
  int? get uid => _uid;
  String? get password => _password;
  String? get rememberedUsername => _rememberedUsername;
  String? get rememberedPassword => _rememberedPassword;
  bool get hasStoredCredentials =>
      _rememberedUid != null && _rememberedPassword != null;
  SavedSessionRestoreStatus get savedSessionRestoreStatus =>
      _savedSessionRestoreStatus;
  bool get isLoggedIn => _currentUser != null && _uid != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberedUid = prefs.getInt('auth_uid');
    _rememberedUsername = prefs.getString('auth_username');
    _rememberedPassword = prefs.getString('auth_password');
    _savedSessionRestoreStatus = SavedSessionRestoreStatus.idle;
  }

  Future<bool> restoreSavedSession() async {
    if (!hasStoredCredentials) return false;

    _savedSessionRestoreStatus = SavedSessionRestoreStatus.restoring;
    notifyListeners();

    final savedUid = _rememberedUid!;
    final savedPassword = _rememberedPassword!;

    try {
      final profile = await TfApiClient.instance.getUserByUid(savedUid, avatarVersion: _avatarVersion);
      if (profile != null && _rememberedUsername == null) {
        _rememberedUsername = profile.username;
      }
      final valid = await TfApiClient.instance.login(savedUid, savedPassword);
      if (valid && profile != null) {
        _uid = savedUid;
        _password = savedPassword;
        _currentUser = profile;
        _rememberedUsername ??= profile.username;
        _savedSessionRestoreStatus = SavedSessionRestoreStatus.succeeded;

        final prefs = await SharedPreferences.getInstance();
        await _persistCredentials(
          prefs,
          uid: savedUid,
          username: _rememberedUsername ?? profile.username,
          password: savedPassword,
        );

        notifyListeners();
        return true;
      } else {
        talker.warning(
          'AuthState.restoreSavedSession: saved session was rejected by the server.',
        );
      }
    } catch (e, stackTrace) {
      talker.error('AuthState.restoreSavedSession failed', e, stackTrace);
    }

    _uid = null;
    _password = null;
    _currentUser = null;
    _savedSessionRestoreStatus = SavedSessionRestoreStatus.failed;
    notifyListeners();
    return false;
  }

  void clearSavedSessionRestoreFailure() {
    if (_savedSessionRestoreStatus != SavedSessionRestoreStatus.failed) {
      return;
    }

    _savedSessionRestoreStatus = SavedSessionRestoreStatus.idle;
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    try {
      final profile =
          await TfApiClient.instance.getUserByUsername(username);
      if (profile == null) {
        return 'userNotFound';
      }

      final uid = int.tryParse(profile.uid);
      if (uid == null) return 'serverError';

      final success = await TfApiClient.instance.login(uid, password);
      if (!success) {
        return 'invalidCredentials';
      }

      _uid = uid;
      _password = password;
      _currentUser = profile;
      _rememberedUid = uid;
      _rememberedUsername = profile.username;
      _rememberedPassword = password;
      _savedSessionRestoreStatus = SavedSessionRestoreStatus.idle;

      final prefs = await SharedPreferences.getInstance();
      await _persistCredentials(
        prefs,
        uid: uid,
        username: profile.username,
        password: password,
      );

      notifyListeners();
      return null;
    } catch (e) {
      talker.error('AuthState.login failed', e);
      return 'networkError';
    }
  }

  Future<void> logout() async {
    _uid = null;
    _password = null;
    _currentUser = null;
    _rememberedUid = null;
    _rememberedUsername = null;
    _rememberedPassword = null;
    _savedSessionRestoreStatus = SavedSessionRestoreStatus.idle;
    final prefs = await SharedPreferences.getInstance();
    await _clearStorage(prefs);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (_uid == null) return;
    try {
      final profile = await TfApiClient.instance.getUserByUid(_uid!, avatarVersion: _avatarVersion);
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

  Future<void> _clearStorage(SharedPreferences prefs) async {
    await prefs.remove('auth_uid');
    await prefs.remove('auth_username');
    await prefs.remove('auth_password');
  }

  Future<void> _persistCredentials(
    SharedPreferences prefs, {
    required int uid,
    required String username,
    required String password,
  }) async {
    await prefs.setInt('auth_uid', uid);
    await prefs.setString('auth_username', username);
    await prefs.setString('auth_password', password);
  }
}
