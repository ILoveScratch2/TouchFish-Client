import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../utils/talker.dart';
import 'api/tf_api_client.dart';

class AuthState extends ChangeNotifier {
  static AuthState? _instance;
  static AuthState get instance => _instance ??= AuthState._();
  AuthState._();

  UserProfile? _currentUser;
  int? _uid;
  String? _password;

  UserProfile? get currentUser => _currentUser;
  int? get uid => _uid;
  String? get password => _password;
  bool get isLoggedIn => _currentUser != null && _uid != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getInt('auth_uid');
    final savedPassword = prefs.getString('auth_password');

    if (savedUid == null || savedPassword == null) return;

    try {
      final profile = await TfApiClient.instance.getUserByUid(savedUid);
      final valid = await TfApiClient.instance.login(savedUid, savedPassword);
      if (valid && profile != null) {
        _uid = savedUid;
        _password = savedPassword;
        _currentUser = profile;
        notifyListeners();
      } else {
        await _clearStorage(prefs);
      }
    } catch (e) {
      talker.warning('AuthState.init: auto-login failed (possibly offline)');
    }
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('auth_uid', uid);
      await prefs.setString('auth_password', password);

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
    final prefs = await SharedPreferences.getInstance();
    await _clearStorage(prefs);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (_uid == null) return;
    try {
      final profile = await TfApiClient.instance.getUserByUid(_uid!);
      if (profile != null) {
        _currentUser = profile;
        notifyListeners();
      }
    } catch (e) {
      talker.error('AuthState.refreshProfile failed', e);
    }
  }

  Future<void> _clearStorage(SharedPreferences prefs) async {
    await prefs.remove('auth_uid');
    await prefs.remove('auth_password');
  }
}
