import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/services/auth_state.dart';
import 'package:touchfish_client/services/inline_reply_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('background isolate initializes AuthState and resolves legacy credentials',
      () async {
    SharedPreferences.setMockInitialValues({
      'auth_uid': 7,
      'auth_username': 'alice',
      'auth_password': 'plain-pw',
    });

    // 背景 isolate 不会执行 main()，AuthState 只会在这里被按需初始化
    final credentials = await InlineReplyService.resolveCredentials();

    expect(credentials, isNotNull);
    expect(credentials!.uid, 7);
    expect(credentials.password, 'plain-pw');
    expect(AuthState.instance.rememberedUid, 7);
  });

  test('jwt mode resolves without a password', () async {
    SharedPreferences.setMockInitialValues({
      'auth_uid': 7,
      'auth_username': 'alice',
      'auth_token': 'jwt-token',
      'auth_refresh_token': 'refresh-token',
      'auth_token_expires_at': 1900000000,
    });
    await AuthState.instance.init();
    expect(AuthState.instance.isJwtMode, isTrue);

    final credentials = await InlineReplyService.resolveCredentials();

    // JWT 模式下没有密码是正常的：请求会带 token，旧实现会在这里直接放弃
    expect(credentials, isNotNull);
    expect(credentials!.uid, 7);
    expect(credentials.password, isEmpty);
  });
}
