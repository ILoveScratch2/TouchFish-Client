import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/services/auth_state.dart';

const MethodChannel _channel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_uid': 7,
      'auth_username': 'alice',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      throw MissingPluginException('secure storage unavailable');
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('restore reports a credentials failure instead of silently logging out',
      () async {
    await AuthState.instance.init();
    expect(AuthState.instance.hasStoredCredentials, isFalse);
    expect(AuthState.instance.rememberedUid, 7);

    final restored = await AuthState.instance.restoreSavedSession();

    // 不能只返回 false 停在 idle
    expect(restored, isFalse);
    expect(
      AuthState.instance.savedSessionRestoreStatus,
      SavedSessionRestoreStatus.failed,
    );
    expect(
      AuthState.instance.restoreFailureReason,
      RestoreFailureReason.credentials,
    );
  });

  test('markSavedSessionRestoreSkipped correctly updates status and stops awaiting', () async {
    SharedPreferences.setMockInitialValues({
      'auth_uid': 7,
      'auth_username': 'alice',
      'auth_token': 'token-value',
    });
    await AuthState.instance.init();

    expect(AuthState.instance.hasStoredCredentials, isTrue);
    expect(AuthState.instance.isLoggedIn, isFalse);
    // 首帧
    expect(AuthState.instance.isAwaitingSavedSession, isTrue);

    AuthState.instance.markSavedSessionRestoreSkipped();

    expect(
      AuthState.instance.savedSessionRestoreStatus,
      SavedSessionRestoreStatus.skipped,
    );
    expect(AuthState.instance.isAwaitingSavedSession, isFalse);
  });
}
