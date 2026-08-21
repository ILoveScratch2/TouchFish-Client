import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 我们需要一个锁定服务来保护 TouchFish 客户端的安全性，避免 wyf 的机密数据被 jc
/// 这非常重要！
class LockService extends ChangeNotifier {
  static LockService? _instance;
  static LockService get instance => _instance ??= LockService._();

  LockService._();

  static const String _keySalt = 'lock_salt';
  static const String _keyHash = 'lock_hash';
  static const String _keyBiometric = 'lock_biometric_enabled';
  static const int _iterations = 120000;

  SharedPreferences? _prefs;
  String? _salt;
  String? _hash;
  bool _biometricEnabled = false;
  bool _locked = false;

  Future<bool> Function(String reason)? biometricPrompt;

  Future<bool> Function()? biometricAvailabilityOverride;

  bool get isEnabled => _hash != null;
  bool get isLocked => _locked;
  bool get isBiometricEnabled => _biometricEnabled;

  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _salt = _prefs!.getString(_keySalt);
    _hash = _prefs!.getString(_keyHash);
    _biometricEnabled = _prefs!.getBool(_keyBiometric) ?? false;
    _locked = isEnabled;
    notifyListeners();
  }

  Future<void> enableMasterPassword(String password) async {
    final salt = _randomBytes(16);
    final hash = await _derivePassword(password, salt);
    _salt = _encode(salt);
    _hash = _encode(hash);
    await _prefs!.setString(_keySalt, _salt!);
    await _prefs!.setString(_keyHash, _hash!);
    _locked = false;
    notifyListeners();
  }

  Future<bool> verifyPassword(String password) async {
    if (!isEnabled || _salt == null || _hash == null) return false;
    final expected = await _derivePassword(password, _decode(_salt!));
    return _constantTimeEquals(expected, _decode(_hash!));
  }

  Future<bool> unlockWithPassword(String password) async {
    final ok = await verifyPassword(password);
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  Future<void> changeMasterPassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (!await verifyPassword(currentPassword)) {
      throw const LockException('incorrectPassword');
    }
    await enableMasterPassword(newPassword);
  }

  Future<void> disableMasterPassword(String password) async {
    if (!await verifyPassword(password)) {
      throw const LockException('incorrectPassword');
    }
    _salt = null;
    _hash = null;
    _biometricEnabled = false;
    await _prefs!.remove(_keySalt);
    await _prefs!.remove(_keyHash);
    await _prefs!.remove(_keyBiometric);
    _locked = false;
    notifyListeners();
  }

  Future<void> lock() async {
    if (!isEnabled) return;
    _locked = true;
    notifyListeners();
  }

  Future<bool> isBiometricAvailable() async {
    final override = biometricAvailabilityOverride;
    if (override != null) return override();
    if (kIsWeb) return false;
    try {
      final auth = LocalAuthentication();
      return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<void> enableBiometric() async {
    if (!isEnabled) {
      throw const LockException('passwordRequired');
    }
    if (!await isBiometricAvailable()) {
      throw const LockException('biometricUnavailable');
    }
    final prompt = biometricPrompt ?? _defaultBiometricPrompt;
    final authenticated = await prompt('Enable biometric unlock for TouchFish');
    if (!authenticated) {
      throw const LockException('biometricCancelled');
    }
    _biometricEnabled = true;
    await _prefs!.setBool(_keyBiometric, true);
    notifyListeners();
  }

  Future<void> disableBiometric() async {
    _biometricEnabled = false;
    await _prefs!.setBool(_keyBiometric, false);
    notifyListeners();
  }

  Future<bool> unlockWithBiometrics() async {
    if (!isBiometricEnabled) {
      throw const LockException('biometricNotEnabled');
    }
    if (!await isBiometricAvailable()) {
      throw const LockException('biometricUnavailable');
    }
    final prompt = biometricPrompt ?? _defaultBiometricPrompt;
    final authenticated = await prompt('Unlock your TouchFish app');
    if (!authenticated) {
      throw const LockException('biometricCancelled');
    }
    _locked = false;
    notifyListeners();
    return true;
  }

  Future<bool> _defaultBiometricPrompt(String reason) async {
    final auth = LocalAuthentication();
    return auth.authenticate(
      localizedReason: reason,
      biometricOnly: true,
    );
  }

  Future<Uint8List> _derivePassword(String password, Uint8List salt) => compute(
    _derivePasswordHash,
    (password: password, salt: salt, iterations: _iterations),
    debugLabel: 'TouchFish password derivation',
  );

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => Random.secure().nextInt(256)));

  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  String _encode(List<int> bytes) => base64Encode(bytes);
  Uint8List _decode(String value) => Uint8List.fromList(base64.decode(value));
}

typedef _PasswordDerivationInput = ({
  String password,
  Uint8List salt,
  int iterations,
});

Uint8List _derivePasswordHash(_PasswordDerivationInput input) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(input.salt, input.iterations, 32));
  return derivator.process(Uint8List.fromList(utf8.encode(input.password)));
}

class LockException implements Exception {
  const LockException(this.code);
  final String code;

  @override
  String toString() => code;
}
