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
      expect(config.maxRequestMessageLength, 200);
    });

    test('parses max_request_message_length', () {
      final config = TfServerConfig.fromJson(const {
        'server_name': 'X',
        'max_request_message_length': 500,
      });
      expect(config.maxRequestMessageLength, 500);
    });

    test('parses min_search_length with default 2', () {
      final config = TfServerConfig.fromJson(const {
        'server_name': 'X',
        'min_search_length': 3,
      });
      expect(config.minSearchLength, 3);

      final fallback = TfServerConfig.fromJson(const {'server_name': 'X'});
      expect(fallback.minSearchLength, 2);
    });

    test('parses features and settings_spec', () {
      final config = TfServerConfig.fromJson(const {
        'server_name': 'X',
        'features': {
          'chat': {'private_chat': false, 'group_chat': true},
          'forum': false,
        },
        'settings_spec': [
          {
            'key': 'max_message_length',
            'type': 'int',
            'min': 1,
            'default': 10000,
            'category': 'limits',
          },
          {
            'key': 'file_download_mode',
            'type': 'enum',
            'options': ['redirect', 'proxy'],
            'default': 'redirect',
            'category': 'storage',
          },
        ],
      });

      expect(config.features.privateChat, isFalse);
      expect(config.features.groupChat, isTrue);
      expect(config.features.forum, isFalse);
      expect(config.features.sticker, isTrue, reason: '缺省按开启');
      expect(config.settingsSpec, hasLength(2));
      expect(config.settingsSpec.first.key, 'max_message_length');
      expect(config.settingsSpec.first.type, 'int');
      expect(config.settingsSpec.first.min, 1);
      expect(config.settingsSpec.last.options, ['redirect', 'proxy']);
    });

    test('features default to all enabled when absent', () {
      final config = TfServerConfig.fromJson(const {'server_name': 'X'});
      expect(config.features.privateChat, isTrue);
      expect(config.features.groupChat, isTrue);
      expect(config.features.groupCreate, isTrue);
      expect(config.features.friendRequest, isTrue);
      expect(config.features.forum, isTrue);
      expect(config.features.sticker, isTrue);
      expect(config.features.announcement, isTrue);
      expect(config.settingsSpec, isEmpty);
    });

    test('features toJson round-trips', () {
      const flags = TfFeatureFlags(
        privateChat: false,
        groupChat: true,
        groupCreate: false,
        friendRequest: true,
        forum: false,
        sticker: true,
        announcement: false,
      );
      final round = TfFeatureFlags.fromJson(flags.toJson());
      expect(round.privateChat, isFalse);
      expect(round.groupChat, isTrue);
      expect(round.groupCreate, isFalse);
      expect(round.friendRequest, isTrue);
      expect(round.forum, isFalse);
      expect(round.sticker, isTrue);
      expect(round.announcement, isFalse);
    });
  });
}
