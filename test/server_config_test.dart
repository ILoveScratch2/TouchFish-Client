import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';

void main() {
  group('TfServerConfig.fromJson', () {
    test('parses previously unsupported server settings', () {
      final config = TfServerConfig.fromJson(const {
        'server_name': 'TouchFish',
        'captcha': true,
        'captcha_provider': 'turnstile',
        'captcha_site_key': 'site-key',
        'media_features': false,
        'file_download_mode': 'proxy',
        'jwt_refresh_expires_seconds': 1209600,
        'min_group_name_length': 2,
        'max_group_name_length': 80,
        'min_username_length': 5,
        'min_password_length': 8,
        'max_sign_length': 120,
        'max_introduction_length': 800,
        'max_post_content_length': 40000,
        'max_avatar_size': 2048,
        'user_storage_quota': 1048576,
        'max_user_storage_quota': 524288,
        'max_sticker_storage_quota': 262144,
      });

      expect(config.captchaProvider, 'turnstile');
      expect(config.captchaSiteKey, 'site-key');
      expect(config.mediaFeatures, isFalse);
      expect(config.fileDownloadMode, 'proxy');
      expect(config.jwtRefreshExpiresSeconds, 1209600);
      expect(config.minGroupNameLength, 2);
      expect(config.maxGroupNameLength, 80);
      expect(config.minUsernameLength, 5);
      expect(config.minPasswordLength, 8);
      expect(config.maxSignLength, 120);
      expect(config.maxIntroductionLength, 800);
      expect(config.maxPostContentLength, 40000);
      expect(config.maxAvatarSize, 2048);
      expect(config.userStorageQuota, 1048576);
      expect(config.maxUserStorageQuota, 524288);
      expect(config.maxStickerStorageQuota, 262144);
    });

    test('applies defaults when new fields are absent', () {
      final config = TfServerConfig.fromJson(const {'server_name': 'X'});

      expect(config.captchaProvider, 'image');
      expect(config.mediaFeatures, isTrue);
      expect(config.fileDownloadMode, isNull);
      expect(config.jwtRefreshExpiresSeconds, isNull);
      expect(config.maxSignLength, isNull);
      expect(config.maxAvatarSize, isNull);
      expect(config.userStorageQuota, isNull);
    });
  });
}
