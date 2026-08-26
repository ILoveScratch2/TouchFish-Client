import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/settings_service.dart';
import '../routes/app_routes.dart';
import '../utils/talker.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/untrusted_image_placeholder.dart';
import 'browser_storage.dart';
import 'domain_trust_service.dart';
import 'search_engines.dart';

/// 新的链接打开！
class BrowserService {
  BrowserService._();

  static final BrowserService instance = BrowserService._();

  static const String kLinkOpenModeKey = 'linkOpenMode';
  static const String kLinkOpenModeInapp = 'inapp';
  static const String kLinkOpenModeExternal = 'external';

  bool get _useInAppBrowser =>
      !kIsWeb &&
      Platform.isAndroid &&
      SettingsService.instance.getValue<String>(
            kLinkOpenModeKey,
            kLinkOpenModeInapp,
          ) ==
          kLinkOpenModeInapp;

  /// 为了防止 wyf 输入的链接有问题，我们帮帮他吧
  static String normalizeUrl(String input) {
    var s = input.trim();
    if (!s.contains('://') && !s.startsWith('about:')) {
      s = 'http://$s';
    }
    return s;
  }

  /// 根据搜索引擎与查询词构造搜索 URL。
  static String searchUrl(String engine, String query) {
    return SearchEngineConfig.byId(engine)?.searchUrl(query) ??
        SearchEngineConfig.defaultEngine.searchUrl(query);
  }

  /// 解析 intent:// 链接中的 browser_fallback_url（对照 Telegram
  static String? intentFallbackUrl(String intentUrl) {
    const marker = 'S.browser_fallback_url=';
    final idx = intentUrl.indexOf(marker);
    if (idx < 0) return null;
    final start = idx + marker.length;
    final end = intentUrl.indexOf(';', start);
    final raw = end < 0
        ? intentUrl.substring(start)
        : intentUrl.substring(start, end);
    if (raw.isEmpty) return null;
    return Uri.decodeComponent(raw);
  }

  Future<void> openUri(BuildContext context, Uri uri) async {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      try {
        await launchUrl(uri);
      } catch (e) {
        talker.error('Failed to open URI: $uri', e);
      }
      return;
    }

    if (await BrowserStorage.instance.isAlwaysExternal(uri.host)) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        talker.error('Failed to open URL externally: $uri', e);
      }
      return;
    }

    if (!context.mounted) return;
    final proceed = await _confirmIfUntrusted(context, uri);
    if (!proceed) return;

    if (_useInAppBrowser) {
      if (!context.mounted) return;
      context.push(AppRoutes.browser, extra: uri.toString());
    } else {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        talker.error('Failed to open URL externally: $uri', e);
      }
    }
  }

  Future<bool> _confirmIfUntrusted(BuildContext context, Uri uri) async {
    final trustService = DomainTrustService.instance;
    if (!trustService.linkProtectionEnabled ||
        await trustService.isTrustedUrl(uri)) {
      return true;
    }
    if (!context.mounted) return false;
    return _confirmUntrustedLink(context, uri);
  }
  static Future<bool> _confirmUntrustedLink(
    BuildContext context,
    Uri uri,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isHttp = uri.scheme == 'http';
    final trustService = DomainTrustService.instance;
    final suggestTrust = await trustService.shouldSuggestTrust(uri.host);
    if (!context.mounted) return false;
    final trustChecked = ValueNotifier<bool>(false);

    final message = [
      l10n.domainTrustLinkUntrustedMessage,
      uri.toString(),
      if (isHttp) l10n.domainTrustLinkHttpWarning,
    ].join('\n\n');

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        if (suggestTrust) ...[
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: trustChecked,
            builder: (context, checked, _) => CheckboxListTile(
              value: checked,
              onChanged: (value) => trustChecked.value = value ?? false,
              title: Text(l10n.domainTrustAddToTrustedDomains),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: () => showDomainTrustInfo(context),
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            tooltip: l10n.domainTrustInfoTitle,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );

    final result = await showTouchFishInfoDialog<String>(
      context,
      title: l10n.domainTrustLinkWarningTitle,
      message: message,
      content: content,
      icon: isHttp ? Icons.warning_amber_rounded : Icons.shield_outlined,
      actions: [
        TouchFishDialogAction<String>(
          label: l10n.domainTrustCopyLink,
          result: 'copy',
        ),
        TouchFishDialogAction<String>(label: l10n.cancel, result: 'cancel'),
        TouchFishDialogAction<String>(
          label: l10n.domainTrustOpenAnyway,
          result: 'open',
          isPrimary: true,
          isDestructive: isHttp,
        ),
      ],
    );

    if (result == 'copy') {
      Clipboard.setData(ClipboardData(text: uri.toString()));
    }
    if (result == 'open') {
      await trustService.recordConfirmedOpen(uri);
      if (trustChecked.value) {
        await trustService.addTrustedDomain(uri.host);
      }
    }
    return result == 'open';
  }
}
