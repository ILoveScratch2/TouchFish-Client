import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/settings_service.dart';
import '../routes/app_routes.dart';
import '../services/browser_service.dart';
import '../services/browser_session.dart';
import '../services/browser_storage.dart';
import '../services/domain_trust_service.dart';
import '../services/media_proxy_service.dart';
import '../services/search_engines.dart';
import '../utils/talker.dart';

/// Make WebView Great Again
const String _kThemeColorScript = r'''
(function() {
  var bridge = window.flutter_inappwebview;
  if (!bridge) return;
  function report() {
    var m = document.querySelector('meta[name="theme-color"]');
    if (m && m.content) bridge.callHandler('tfThemeColor', String(m.content));
  }
  report();
  setTimeout(report, 600);
})();
''';

/// Darker Please
const String _kDarkModeScript = r'''
(function() {
  if (!document.querySelector('meta[name="color-scheme"]')) {
    var m = document.createElement('meta');
    m.name = 'color-scheme';
    m.content = 'dark';
    document.head.appendChild(m);
  }
})();
''';

class BrowserScreen extends StatefulWidget {
  final String? initialUrl;

  const BrowserScreen({super.key, this.initialUrl});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static String? _userAgent;
  static String? _defaultUserAgent;
  static bool? _mixedContentAllowed;

  bool _addressEditing = false;
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  Timer? _suggestTimer;
  List<String> _suggestions = const [];

  bool _findActive = false;
  final TextEditingController _findController = TextEditingController();
  int _findActiveMatch = 0;
  int? _findTotal;

  bool? _bookmarked;
  bool _allowPop = false;

  /// 新标签页「最近访问」数据源。
  final Future<List<Map<String, dynamic>>> _recentVisitsFuture =
      BrowserStorage.instance.getHistory();

  BrowserSession get _session => BrowserSession.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_syncBrowserSettings());
    final initial = widget.initialUrl;
    if (_session.isEmpty) {
      _createTab(
        initial != null && initial.trim().isNotEmpty
            ? BrowserService.normalizeUrl(initial.trim())
            : 'about:blank',
      );
    } else if (initial != null && initial.trim().isNotEmpty) {
      _openOrReuse(BrowserService.normalizeUrl(initial.trim()));
    } else {
      _refreshBookmarkState();
    }
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _addressController.dispose();
    _addressFocus.dispose();
    _findController.dispose();
    super.dispose();
  }

  BrowserTab get _activeTab => _session.activeTab;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  static Future<String> _resolveUserAgent() async {
    final custom = SettingsService.instance.getValue<String>(
      'browserUserAgent',
      '',
    );
    if (custom.trim().isNotEmpty) return custom.trim();
    return _buildDefaultUserAgent();
  }

  static bool _isMixedContentAllowed() =>
      SettingsService.instance.getValue<String>(
        'browserMixedContent',
        'block',
      ) ==
      'allow';

  static Future<String> _buildDefaultUserAgent() async {
    if (_defaultUserAgent != null) return _defaultUserAgent!;
    try {
      final info = await PackageInfo.fromPlatform();
      var ua = await InAppWebViewController.getDefaultUserAgent();
      ua = ua.replaceAll('; wv)', ')');
      _defaultUserAgent = '$ua TouchFish/${info.version}';
    } catch (e) {
      talker.error('Failed to build custom user agent', e);
      _defaultUserAgent = '';
    }
    return _defaultUserAgent!;
  }

  Future<void> _syncBrowserSettings() async {
    final ua = await _resolveUserAgent();
    final mixedContentAllowed = _isMixedContentAllowed();
    if (ua == _userAgent && mixedContentAllowed == _mixedContentAllowed) {
      if (mounted) setState(() {});
      return;
    }
    _userAgent = ua;
    _mixedContentAllowed = mixedContentAllowed;
    for (final tab in _session.tabs) {
      final controller = tab.controller;
      if (controller == null) continue;
      await controller.setSettings(
        settings: InAppWebViewSettings(
          userAgent: ua.isEmpty ? null : ua,
          mixedContentMode: mixedContentAllowed
              ? MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW
              : MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
        ),
      );
      controller.reload();
    }
    if (mounted) setState(() {});
  }

  BrowserTab _createTab(String url, {bool forceNew = false}) {
    late final BrowserTab tab;
    tab = _session.createTab(url, onFindResult: (active, total, done) {
      if (!mounted || _session.activeTab.id != tab.id) return;
      setState(() {
        _findActiveMatch = active;
        _findTotal = done ? total : null;
      });
    });
    if (!forceNew) {
      _refreshBookmarkState();
    }
    return tab;
  }

  void _openNewTab(String url) {
    if (url.trim().isEmpty) return;
    final s = _session;
    if (s.count >= kMaxBrowserTabs) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.browserTabLimitReached)));
      return;
    }
    setState(() => _createTab(BrowserService.normalizeUrl(url)));
  }

  void _openOrReuse(String url) {
    final s = _session;
    final existing = s.indexOfUrl(url);
    setState(() {
      if (existing != null) {
        s.currentIndex = existing;
      } else {
        _createTab(url);
      }
      _refreshBookmarkState();
    });
  }

  Future<void> _closeTab(BrowserTab tab) async {
    final s = _session;
    final index = s.tabs.indexOf(tab);
    if (index < 0) return;
    await s.closeTab(index);
    if (!mounted) return;
    if (s.isEmpty) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    } else {
      setState(() => _refreshBookmarkState());
    }
  }

  Future<void> _exitBrowser() async {
    final s = _session;
    await s.clearAll();
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  void _loadInActiveTab(String url) {
    final u = BrowserService.normalizeUrl(url);
    final controller = _activeTab.controller;
    if (controller == null) {
      setState(() => _activeTab.url = u);
      return;
    }
    controller.loadUrl(urlRequest: URLRequest(url: WebUri(u)));
  }

  void _submitAddress(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      setState(() {
        _addressEditing = false;
        _suggestions = const [];
      });
      return;
    }
    final looksLikeUrl = input.contains('.') && !input.contains(' ');
    final engine = SettingsService.instance.getValue<String>(
      'browserSearchEngine',
      'bing',
    );
    _loadInActiveTab(
      looksLikeUrl ? input : BrowserService.searchUrl(engine, input),
    );
    setState(() {
      _addressEditing = false;
      _suggestions = const [];
    });
  }

  void _onAddressChanged(String query) {
    _suggestTimer?.cancel();
    final q = query.trim();
    final looksLikeUrl = q.contains('.') && !q.contains(' ');
    if (q.isEmpty || looksLikeUrl) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = const []);
      }
      return;
    }
    _suggestTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_loadSuggestions(q));
    });
  }

  Future<void> _loadSuggestions(String query) async {
    final engine = SearchEngineConfig.byId(
      SettingsService.instance.getValue<String>(
        'browserSearchEngine',
        'bing',
      ),
    );
    if (engine == null) return;
    final url = engine.autocompleteUrl(query);
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return;
      final suggestions = parseSuggestions(response.body);
      if (!mounted || !_addressEditing) return;
      setState(() => _suggestions = suggestions);
    } catch (e) {
      talker.debug('Autocomplete failed for $url', e);
    }
  }

  Future<void> _copyCurrentUrl() async {
    final url = _activeTab.url;
    if (url.isEmpty || url == 'about:blank') return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.browserCopied)));
  }

  void _refreshBookmarkState() {
    final url = _activeTab.url;
    if (url.isEmpty || url == 'about:blank') {
      _bookmarked = false;
      return;
    }
    unawaited(
      BrowserStorage.instance.isBookmarked(url).then((value) {
        if (!mounted || _activeTab.url != url) return;
        setState(() => _bookmarked = value);
      }),
    );
  }

  Future<void> _toggleBookmark() async {
    final tab = _activeTab;
    final url = tab.url;
    if (url.isEmpty || url == 'about:blank') return;
    final storage = BrowserStorage.instance;
    final wasBookmarked = await storage.isBookmarked(url);
    if (wasBookmarked) {
      await storage.removeBookmark(url);
    } else {
      await storage.addBookmark(url, tab.title ?? url);
    }
    if (!mounted) return;
    setState(() => _bookmarked = !wasBookmarked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasBookmarked ? l10n.browserBookmarkRemoved : l10n.browserBookmarkAdded,
        ),
      ),
    );
  }

  /// 打开书签/历史全屏页，选中条目后在新标签页打开（对照 Telegram
  Future<void> _openListPage(String route) async {
    final url = await context.push<String>(route);
    if (url != null && url.isNotEmpty && mounted) {
      _openNewTab(url);
    }
  }

  Future<void> _showBookmarksSheet() => _openListPage(AppRoutes.browserBookmarks);

  Future<void> _showHistorySheet() => _openListPage(AppRoutes.browserHistory);

  Future<void> _shareCurrentUrl() async {
    final url = _activeTab.url;
    if (url.isEmpty || url == 'about:blank') return;
    await SharePlus.instance.share(ShareParams(text: url));
  }

  /// 清除浏览数据（对照 Telegram WebBrowserSettings 的清缓存/清 Cookie/
  /// 清历史入口，并支持按时间范围）。Cookie 无时间属性，按「时间范围内
  /// 历史记录中的域名」逐个清除；选中全部时间时兜底全清。
  Future<void> _showClearBrowsingDataDialog() async {
    final l10n = AppLocalizations.of(context)!;
    var range = 0;
    var clearHistory = true;
    var clearCookies = false;
    var clearCache = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.browserClearDataTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.browserClearDataDesc,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                RadioGroup<int>(
                  groupValue: range,
                  onChanged: (v) =>
                      setDialogState(() => range = v ?? range),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (value, label) in const [
                        (0, 'browserClearDataRangeHour'),
                        (1, 'browserClearDataRangeDay'),
                        (2, 'browserClearDataRangeWeek'),
                        (3, 'browserClearDataRangeAll'),
                      ])
                        RadioListTile<int>(
                          value: value,
                          title: Text(_l10nLabel(l10n, label)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                CheckboxListTile(
                  value: clearHistory,
                  onChanged: (v) =>
                      setDialogState(() => clearHistory = v ?? false),
                  title: Text(l10n.browserClearDataTypeHistory),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: clearCookies,
                  onChanged: (v) =>
                      setDialogState(() => clearCookies = v ?? false),
                  title: Text(l10n.browserClearDataTypeCookies),
                  subtitle: Text(l10n.browserClearDataCookiesWarning),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: clearCache,
                  onChanged: (v) =>
                      setDialogState(() => clearCache = v ?? false),
                  title: Text(l10n.browserClearDataTypeCache),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.browserClearDataConfirm),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _clearBrowsingData(range, clearHistory, clearCookies, clearCache);
  }

  String _l10nLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'browserClearDataRangeHour':
        return l10n.browserClearDataRangeHour;
      case 'browserClearDataRangeDay':
        return l10n.browserClearDataRangeDay;
      case 'browserClearDataRangeWeek':
        return l10n.browserClearDataRangeWeek;
      default:
        return l10n.browserClearDataRangeAll;
    }
  }

  Future<void> _clearBrowsingData(
    int range,
    bool clearHistory,
    bool clearCookies,
    bool clearCache,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final cutoff = switch (range) {
      0 => now.subtract(const Duration(hours: 1)),
      1 => now.subtract(const Duration(days: 1)),
      2 => now.subtract(const Duration(days: 7)),
      _ => null,
    };
    final storage = BrowserStorage.instance;

    if (clearHistory) {
      await storage.clearHistoryBefore(cutoff);
    }
    if (clearCookies) {
      final manager = CookieManager.instance();
      try {
        if (cutoff == null) {
          await manager.deleteAllCookies();
        } else {
          final domains = await storage.historyDomainsBefore(cutoff);
          for (final domain in domains) {
            await manager.deleteCookies(url: WebUri('https://$domain/'));
          }
        }
      } catch (e) {
        talker.error('Failed to clear cookies', e);
      }
    }
    if (clearCache) {
      for (final tab in _session.tabs) {
        final controller = tab.controller;
        if (controller == null) continue;
        try {
          await controller.clearCache();
        } catch (e) {
          talker.error('Failed to clear webview cache', e);
        }
      }
      await MediaProxyService.instance.clearCache();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.browserClearDataDone)));
  }

  Future<void> _openExternal(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.browserOpenFailed)));
    }
  }

  Future<void> _openExternalAndTrust(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) {
      await _openExternal(Uri.parse(url));
      return;
    }
    final storage = BrowserStorage.instance;
    final alwaysExternal = await storage.isAlwaysExternal(uri.host);
    if (!mounted) return;
    final remember = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          alwaysExternal
              ? l10n.browserCancelAlwaysExternalTitle
              : l10n.browserRememberDomainTitle,
        ),
        content: Text(
          alwaysExternal
              ? l10n.browserCancelAlwaysExternalMessage(uri.host)
              : l10n.browserRememberDomainMessage(uri.host),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              alwaysExternal ? l10n.cancel : l10n.browserOpenAnyway,
            ),
          ),
        ],
      ),
    );
    if (remember == true) {
      if (alwaysExternal) {
        await storage.removeAlwaysExternalDomain(uri.host);
      } else {
        await storage.addAlwaysExternalDomain(uri.host);
        await DomainTrustService.instance.addTrustedDomain(uri.host);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              alwaysExternal
                  ? l10n.browserAlwaysExternalDisabled(uri.host)
                  : l10n.browserAlwaysExternalEnabled(uri.host),
            ),
          ),
        );
      }
    }
    await _openExternal(uri);
  }

  /// wyf will you need this?
  Future<void> _showLongPressLinkMenu(String href) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tab_rounded),
              title: Text(l10n.browserOpenInNewTab),
              onTap: () => Navigator.of(context).pop('newtab'),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(l10n.browserOpenInExternal),
              onTap: () => Navigator.of(context).pop('external'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(l10n.browserCopyLink),
              onTap: () => Navigator.of(context).pop('copy'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'newtab':
        _openNewTab(href);
      case 'external':
        await _openExternal(Uri.parse(href));
      case 'copy':
        await Clipboard.setData(ClipboardData(text: href));
    }
  }

  Future<void> _showLongPressImageMenu(String imageUrl) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(l10n.browserOpenInExternal),
              onTap: () => Navigator.of(context).pop('external'),
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: Text(l10n.browserImageMenuDownload),
              onTap: () => Navigator.of(context).pop('download'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(l10n.browserCopyLink),
              onTap: () => Navigator.of(context).pop('copy'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'external':
        await _openExternal(Uri.parse(imageUrl));
      case 'download':
        await _downloadImage(imageUrl);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: imageUrl));
    }
  }

  Future<void> _downloadImage(String imageUrl) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.browserDownloading)));
    try {
      final response = await http
          .get(
            Uri.parse(imageUrl),
            headers: {if (_userAgent != null && _userAgent!.isNotEmpty) 'User-Agent': _userAgent!},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      var filename = segments.isEmpty ? 'image.png' : segments.last;
      if (!filename.contains('.')) filename = '$filename.png';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: response.headers['content-type'])], text: filename),
      );
    } catch (e) {
      talker.error('Failed to download image: $imageUrl', e);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.browserDownloadFailed)));
    }
  }

  Future<void> _showDownloadDialog(DownloadStartRequest request) async {
    final url = request.url.toString();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.browserDownloadTitle),
        content: Text(l10n.browserDownloadMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.browserDownloadOpen),
          ),
        ],
      ),
    );
    if (proceed == true) {
      await _openExternal(Uri.parse(url));
    }
  }

  void _toggleFind() {
    setState(() {
      _findActive = !_findActive;
      if (!_findActive) {
        _findController.clear();
        _findTotal = null;
        _activeTab.findController.clearMatches();
      } else {
        _findController.clear();
        _findTotal = null;
      }
    });
  }

  void _onFindChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _findTotal = null;
        _findActiveMatch = 0;
      });
      _activeTab.findController.clearMatches();
      return;
    }
    _activeTab.findController.findAll(find: query);
  }

  /// true -> handled keyi
  /// false -> not handled, let system handle
  Future<bool> _handleSystemBack() async {
    if (_addressEditing) {
      setState(() => _addressEditing = false);
      return true;
    }
    if (_findActive) {
      _toggleFind();
      return true;
    }
    final controller = _activeTab.controller;
    if (controller != null) {
      final canGoBack = await controller.canGoBack();
      if (canGoBack) {
        controller.goBack();
        return true;
      }
    }
    if (_session.tabs.length > 1) {
      await _closeTab(_activeTab);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final handled = await _handleSystemBack();
        if (handled || !mounted) return;
        setState(() => _allowPop = true);
        navigator.pop();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTabBar(),
              _buildAddressBar(),
              if (_addressEditing && _suggestions.isNotEmpty)
                _buildSuggestionsPanel(),
              const Divider(height: 1),
              Expanded(child: _buildContent()),
              if (_findActive) _buildFindBar(),
              SafeArea(top: false, child: _buildBottomBar()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final s = _session;
    return Container(
      height: 44,
      color: _toolbarBackground(),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          for (var i = 0; i < s.tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _TabChip(
                tab: s.tabs[i],
                selected: i == s.currentIndex,
                foreground: _toolbarForeground(),
                emptyLabel: l10n.browserNewTab,
                onTap: () => setState(() {
                  s.currentIndex = i;
                  _refreshBookmarkState();
                }),
                onClose: () => _closeTab(s.tabs[i]),
              ),
            ),
          IconButton(
            onPressed: () => _openNewTab('about:blank'),
            icon: Icon(Icons.add_rounded, color: _toolbarForeground()),
            visualDensity: VisualDensity.compact,
            tooltip: l10n.browserNewTab,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressBar() {
    final tab = _activeTab;
    final foreground = _toolbarForeground();
    final background = _toolbarBackground();
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => tab.controller?.goBack(),
            icon: Icon(Icons.arrow_back_rounded, color: foreground),
            visualDensity: VisualDensity.compact,
            tooltip: l10n.browserBack,
          ),
          IconButton(
            onPressed: () => tab.controller?.goForward(),
            icon: Icon(Icons.arrow_forward_rounded, color: foreground),
            visualDensity: VisualDensity.compact,
            tooltip: l10n.browserForward,
          ),
          Expanded(
            child: _addressEditing
                ? _buildAddressField(foreground, background)
                : InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      _addressController.text = tab.url == 'about:blank'
                          ? ''
                          : tab.url;
                      setState(() {
                        _addressEditing = true;
                        _suggestions = const [];
                      });
                      _addressFocus.requestFocus();
                    },
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _addressBarBackground(),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tab.failed
                                ? Icons.gpp_bad_outlined
                                : Icons.lock_outline_rounded,
                            size: 14,
                            color: tab.failed
                                ? const Color(0xFFE57373)
                                : foreground.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _displayUrl(tab),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: foreground.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          IconButton(
            onPressed: () {
              final controller = tab.controller;
              if (tab.loading) {
                controller?.stopLoading();
              } else {
                controller?.reload();
              }
            },
            icon: Icon(
              tab.loading ? Icons.close_rounded : Icons.refresh_rounded,
              color: foreground,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: tab.loading ? l10n.browserStop : l10n.browserRefresh,
          ),
          _buildMenu(foreground),
        ],
      ),
    );
  }

  Widget _buildAddressField(Color foreground, Color background) {
    return TextField(
      controller: _addressController,
      focusNode: _addressFocus,
      autofocus: true,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.go,
      style: TextStyle(fontSize: 13, color: foreground),
      cursorColor: foreground,
      decoration: InputDecoration(
        isDense: true,
        hintText: l10n.browserAddressHint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: foreground.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: _addressBarBackground(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          onPressed: () => _submitAddress(_addressController.text),
          icon: Icon(Icons.arrow_forward_rounded, size: 20, color: foreground),
          tooltip: l10n.browserGo,
        ),
      ),
      onChanged: _onAddressChanged,
      onSubmitted: _submitAddress,
    );
  }

  Widget _buildSuggestionsPanel() {
    final foreground = _toolbarForeground();
    return Material(
      color: _menuBackground(),
      elevation: 4,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _suggestions.length,
        itemBuilder: (context, i) {
          final suggestion = _suggestions[i];
          return ListTile(
            dense: true,
            leading: Icon(
              Icons.search_rounded,
              size: 20,
              color: foreground.withValues(alpha: 0.7),
            ),
            title: Text(
              suggestion,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: foreground),
            ),
            onTap: () {
              final engine = SettingsService.instance.getValue<String>(
                'browserSearchEngine',
                'bing',
              );
              _loadInActiveTab(BrowserService.searchUrl(engine, suggestion));
              setState(() {
                _addressEditing = false;
                _suggestions = const [];
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildMenu(Color foreground) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: foreground),
      color: _menuBackground(),
      onSelected: (value) async {
        final url = _activeTab.url;
        switch (value) {
          case 'copy':
            await _copyCurrentUrl();
          case 'find':
            if (url == 'about:blank') return;
            setState(() {
              _findActive = true;
              _findController.clear();
            });
          case 'share':
            await _shareCurrentUrl();
          case 'external':
            if (url == 'about:blank') return;
            await _openExternalAndTrust(url);
          case 'bookmarks':
            await _showBookmarksSheet();
          case 'history':
            await _showHistorySheet();
          case 'cleardata':
            await _showClearBrowsingDataDialog();
          case 'exit':
            await _exitBrowser();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'copy',
          child: ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: Text(l10n.browserCopyLink),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'bookmarks',
          child: ListTile(
            leading: const Icon(Icons.bookmarks_rounded),
            title: Text(l10n.browserBookmarks),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'history',
          child: ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(l10n.browserHistory),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'find',
          child: ListTile(
            leading: const Icon(Icons.search_rounded),
            title: Text(l10n.browserFindOnPage),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: const Icon(Icons.share_rounded),
            title: Text(l10n.browserShare),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'external',
          child: ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(l10n.browserOpenInExternal),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'cleardata',
          child: ListTile(
            leading: const Icon(Icons.delete_sweep_rounded),
            title: Text(l10n.browserClearDataTitle),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'exit',
          child: ListTile(
            leading: const Icon(Icons.exit_to_app_rounded),
            title: Text(l10n.browserExitBrowser),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final s = _session;
    final active = _activeTab;
    final showNewTab = active.url == 'about:blank' &&
        !active.loading &&
        !active.failed;
    return Stack(
      children: [
        IndexedStack(
          index: s.currentIndex,
          children: [
            for (final tab in s.tabs) _buildTabView(tab),
          ],
        ),
        if (showNewTab) _buildNewTabPage(),
        if (_activeTab.loading)
          Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(
              value: _activeTab.progress / 100,
              minHeight: 2,
            ),
          ),
        if (_activeTab.failed) _buildErrorOverlay(),
      ],
    );
  }

  /// 新标签页起始页：搜索框 + 最近访问 + 书签/历史入口。
  Widget _buildNewTabPage() {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Container(
        color: theme.colorScheme.surface,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.public_rounded,
                    size: 52,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      _addressController.text = '';
                      setState(() {
                        _addressEditing = true;
                        _suggestions = const [];
                      });
                      _addressFocus.requestFocus();
                    },
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l10n.browserNewTabSearchPlaceholder,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.browserNewTabRecent,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _recentVisitsFuture,
                    builder: (context, snapshot) {
                      final recent = snapshot.data ?? const [];
                      if (recent.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          for (final item in recent.take(6))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: _recentAvatar(theme, item),
                              title: Text(
                                (item['title'] ?? item['url']) as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                (item['url'] ?? '') as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () =>
                                  _openNewTab((item['url'] ?? '') as String),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _showBookmarksSheet,
                        icon: const Icon(Icons.bookmarks_rounded, size: 18),
                        label: Text(l10n.browserNewTabOpenBookmarks),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: _showHistorySheet,
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: Text(l10n.browserNewTabOpenHistory),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recentAvatar(ThemeData theme, Map<String, dynamic> item) {
    final url = (item['url'] ?? '') as String;
    final title = (item['title'] ?? url) as String;
    final host = Uri.tryParse(url)?.host ?? '';
    final letter = (title.isNotEmpty ? title[0] : (host.isNotEmpty ? host[0] : '?'))
        .toUpperCase();
    final palette = Colors.primaries;
    final color = palette[host.hashCode.abs() % palette.length].shade600;
    return CircleAvatar(
      radius: 14,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Text(
        letter,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// FAILED!
  Widget _buildErrorOverlay() {
    final tab = _activeTab;
    final theme = Theme.of(context);
    final errorText = tab.errorDescription == null ||
            tab.errorDescription!.isEmpty
        ? null
        : tab.errorDescription!;
    return Positioned.fill(
      child: Container(
        color: theme.colorScheme.surface,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.browserLoadingFailed,
                  style: theme.textTheme.titleMedium,
                ),
                if (tab.url.isNotEmpty && tab.url != 'about:blank') ...[
                  const SizedBox(height: 4),
                  Text(
                    tab.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    errorText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => tab.controller?.reload(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.browserRetry),
                    ),
                    if (tab.url != 'about:blank')
                      OutlinedButton.icon(
                        onPressed: () => _openExternalAndTrust(tab.url),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(l10n.browserOpenInExternal),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabView(BrowserTab tab) {
    if (_userAgent == null) {
      return const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    return _TabWebView(
      tab: tab,
      darkMode: _isDark,
      userAgent: _userAgent ?? '',
      mixedContentAllowed: _mixedContentAllowed ?? false,
      onControllerCreated: (controller) {
        tab.controller = controller;
      },
      onState: (title, url, loading, progress, failed) {
        if (!mounted) return;
        setState(() {
          if (title != null) tab.title = title;
          if (url.isNotEmpty && url != tab.url) {
            tab.url = url;
            _refreshBookmarkState();
            if (url != 'about:blank') {
              unawaited(
                BrowserStorage.instance.recordVisit(
                  url,
                  title ?? tab.title ?? url,
                ),
              );
            }
          }
          tab.loading = loading;
          tab.progress = progress;
          tab.failed = failed;
          // 新导航开始即重置错误状态（对照 Telegram onPageStarted 重置）。
          if (loading) {
            tab.errorDescription = null;
          }
        });
      },
      onError: (description) {
        if (!mounted) return;
        setState(() => tab.errorDescription = description);
      },
      onThemeColor: (color) {
        if (!mounted) return;
        setState(() => tab.themeColor = color);
      },
      onLongPressHitTest: (type, extra) {
        if (!mounted || extra.isEmpty) return;
        if (type == InAppWebViewHitTestResultType.IMAGE_TYPE ||
            type == InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE) {
          unawaited(_showLongPressImageMenu(extra));
        } else if (type == InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE) {
          unawaited(_showLongPressLinkMenu(extra));
        }
      },
      onRendererGone: () => unawaited(_handleRendererGone(tab)),
      onOpenExternal: (url) => _openExternal(Uri.parse(url)),
      onDownload: (request) => _showDownloadDialog(request),
      onNewWindow: (url) => _openNewTab(url),
    );
  }

  /// wtf your browser crashed?????
  Future<void> _handleRendererGone(BrowserTab tab) async {
    if (!mounted) return;
    final reload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.browserRendererGoneTitle),
        content: Text(l10n.browserRendererGoneMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.browserCloseTab),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.browserRetry),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (reload == true) {
      final session = _session;
      await session.recycleTab(tab);
      if (mounted) setState(() {});
    } else {
      await _closeTab(tab);
    }
  }

  Widget _buildFindBar() {
    final foreground = _toolbarForeground();
    return Container(
      color: _toolbarBackground(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleFind,
            icon: Icon(Icons.close_rounded, color: foreground),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: TextField(
              controller: _findController,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: foreground),
              cursorColor: foreground,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.browserFindHint,
                hintStyle: TextStyle(
                  color: foreground.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
              ),
              onChanged: _onFindChanged,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _findTotal == null
                ? ''
                : (_findTotal == 0
                      ? l10n.browserNoResults
                      : '${_findActiveMatch + 1}/$_findTotal'),
            style: TextStyle(fontSize: 12, color: foreground),
          ),
          IconButton(
            onPressed: () =>
                _activeTab.findController.findNext(forward: false),
            icon: Icon(Icons.keyboard_arrow_up_rounded, color: foreground),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () => _activeTab.findController.findNext(forward: true),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: foreground),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final foreground = _toolbarForeground();
    return Container(
      color: _toolbarBackground(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () => _openNewTab('about:blank'),
            icon: Icon(Icons.add_rounded, color: foreground),
            tooltip: l10n.browserNewTab,
          ),
          IconButton(
            onPressed: () {
              if (_activeTab.url == 'about:blank') return;
              setState(() {
                _findActive = true;
                _findController.clear();
              });
            },
            icon: Icon(Icons.search_rounded, color: foreground),
            tooltip: l10n.browserFindOnPage,
          ),
          IconButton(
            onPressed: _shareCurrentUrl,
            icon: Icon(Icons.share_rounded, color: foreground),
            tooltip: l10n.browserShare,
          ),
          IconButton(
            onPressed: () {
              if (_activeTab.url == 'about:blank') return;
              _openExternalAndTrust(_activeTab.url);
            },
            icon: Icon(Icons.open_in_new, color: foreground),
            tooltip: l10n.browserOpenInExternal,
          ),
          IconButton(
            onPressed: _toggleBookmark,
            icon: Icon(
              _bookmarked == true
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: foreground,
            ),
            tooltip: _bookmarked == true
                ? l10n.browserRemoveBookmark
                : l10n.browserAddBookmark,
          ),
        ],
      ),
    );
  }

  String _displayUrl(BrowserTab tab) {
    if (tab.url.isEmpty || tab.url == 'about:blank') return '';
    final uri = Uri.tryParse(tab.url);
    if (uri == null) return tab.url;
    var display = tab.url;
    if (uri.path == '/' || uri.path.isEmpty) {
      display = '${uri.scheme}://${uri.host}';
    } else {
      final path = uri.path.endsWith('/')
          ? uri.path.substring(0, uri.path.length - 1)
          : uri.path;
      display = '${uri.scheme}://${uri.host}$path';
    }
    return display;
  }

  Color _toolbarBackground() {
    final theme = Theme.of(context);
    return _activeTab.themeColor ?? theme.colorScheme.surfaceContainerHighest;
  }

  Color _toolbarForeground() {
    final bg = _toolbarBackground();
    return bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  Color _addressBarBackground() {
    final bg = _toolbarBackground();
    return _toolbarForeground() == Colors.white
        ? bg.withValues(alpha: 0.15)
        : bg.withValues(alpha: 0.5);
  }

  Color _menuBackground() {
    final bg = _toolbarBackground();
    return bg.computeLuminance() > 0.5 ? Colors.white : Colors.grey.shade900;
  }
}

class _TabChip extends StatelessWidget {
  final BrowserTab tab;
  final bool selected;
  final Color foreground;
  final String emptyLabel;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabChip({
    required this.tab,
    required this.selected,
    required this.foreground,
    required this.emptyLabel,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final title = tab.title == null || tab.title!.isEmpty
        ? (tab.url == 'about:blank' ? emptyLabel : tab.url)
        : tab.title!;
    return Material(
      color: selected ? _selectedColor(context) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tab.loading) ...[
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: selected ? Colors.white70 : foreground,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : foreground,
                  ),
                ),
              ),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: selected ? Colors.white : foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _selectedColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.colorScheme.primary;
  }
}

class _TabWebView extends StatelessWidget {
  final BrowserTab tab;
  final bool darkMode;
  final String userAgent;
  final bool mixedContentAllowed;
  final ValueChanged<InAppWebViewController> onControllerCreated;
  final void Function(String? title, String url, bool loading, int progress,
      bool failed) onState;
  final ValueChanged<Color> onThemeColor;
  final void Function(InAppWebViewHitTestResultType type, String extra)
      onLongPressHitTest;
  final VoidCallback onRendererGone;
  final ValueChanged<String> onError;
  final ValueChanged<String> onOpenExternal;
  final ValueChanged<DownloadStartRequest> onDownload;
  final ValueChanged<String> onNewWindow;

  const _TabWebView({
    required this.tab,
    required this.darkMode,
    required this.userAgent,
    required this.mixedContentAllowed,
    required this.onControllerCreated,
    required this.onState,
    required this.onThemeColor,
    required this.onLongPressHitTest,
    required this.onRendererGone,
    required this.onError,
    required this.onOpenExternal,
    required this.onDownload,
    required this.onNewWindow,
  });

  Future<void> _injectScripts(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(source: _kThemeColorScript);
      if (darkMode) {
        await controller.evaluateJavascript(source: _kDarkModeScript);
      }
    } catch (e) {
      talker.error('Failed to inject browser scripts', e);
    }
  }

  void _registerJavaScriptHandlers(InAppWebViewController controller) {
    // keepAlive 恢复时 handler 会随 props 恢复 so we nned移除再注册保证幂等
    controller.removeJavaScriptHandler(handlerName: 'tfThemeColor');
    controller.addJavaScriptHandler(handlerName: 'tfThemeColor', callback: (args) {
      if (args.isNotEmpty && args.first is String) {
        final color = _parseHexColor((args.first as String).trim());
        if (color != null) onThemeColor(color);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialUrl = tab.url == 'about:blank' ? null : tab.url;
    return InAppWebView(
      key: ValueKey('${tab.id}-${tab.generation}'),
      keepAlive: tab.keepAlive,
      initialUrlRequest: initialUrl == null
          ? null
          : URLRequest(url: WebUri(initialUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        allowFileAccess: false,
        allowContentAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        supportMultipleWindows: true,
        supportZoom: true,
        builtInZoomControls: true,
        displayZoomControls: false,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        safeBrowsingEnabled: true,
        mediaPlaybackRequiresUserGesture: true,
        userAgent: userAgent.isEmpty ? null : userAgent,
        mixedContentMode: mixedContentAllowed
            ? MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW
            : MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
      ),
      findInteractionController: tab.findController,
      onWebViewCreated: (controller) {
        onControllerCreated(controller);
        _registerJavaScriptHandlers(controller);
      },
      onLongPressHitTestResult: (controller, hitTestResult) {
        final type = hitTestResult.type;
        final extra = hitTestResult.extra;
        if (type == null || extra == null || extra.isEmpty) return;
        onLongPressHitTest(type, extra);
      },
      onRenderProcessGone: (controller, detail) => onRendererGone(),
      onTitleChanged: (controller, title) {
        onState(title, tab.url, tab.loading, tab.progress, tab.failed);
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        final u = url?.toString() ?? '';
        onState(tab.title, u, tab.loading, tab.progress, tab.failed);
      },
      onProgressChanged: (controller, progress) {
        onState(
          tab.title,
          tab.url,
          progress < 100,
          progress,
          tab.failed,
        );
      },
      onLoadStart: (controller, url) {
        onState(tab.title, url?.toString() ?? tab.url, true, 0, false);
        _injectScripts(controller);
      },
      onLoadStop: (controller, url) {
        onState(tab.title, url?.toString() ?? tab.url, false, 100, false);
        _injectScripts(controller);
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true) {
          onError(error.description);
          onState(tab.title, tab.url, false, tab.progress, true);
        }
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url;
        final scheme = url?.scheme.toLowerCase();
        if (scheme == 'http' || scheme == 'https') {
          return NavigationActionPolicy.ALLOW;
        }
        final raw = url?.toString() ?? '';
        if (scheme == 'intent') {
          final fallback = BrowserService.intentFallbackUrl(raw);
          if (fallback != null) {
            controller.loadUrl(urlRequest: URLRequest(url: WebUri(fallback)));
            return NavigationActionPolicy.CANCEL;
          }
        }
        if (raw.isNotEmpty) {
          onOpenExternal(raw);
        }
        return NavigationActionPolicy.CANCEL;
      },
      onCreateWindow: (controller, createWindowAction) async {
        final url = createWindowAction.request.url?.toString() ?? '';
        if (url.isNotEmpty) {
          onNewWindow(url);
        }
        return true;
      },
      onDownloadStartRequest: (controller, downloadStartRequest) {
        final scheme = downloadStartRequest.url.scheme.toLowerCase();
        if (scheme == 'http' || scheme == 'https') {
          onDownload(downloadStartRequest);
        }
      },
      onJsAlert: (controller, jsAlertRequest) async {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(jsAlertRequest.message ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context)!.confirm),
              ),
            ],
          ),
        );
        return JsAlertResponse(action: JsAlertResponseAction.CONFIRM);
      },
      onJsConfirm: (controller, jsConfirmRequest) async {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(jsConfirmRequest.message ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(AppLocalizations.of(context)!.confirm),
              ),
            ],
          ),
        );
        return JsConfirmResponse(
          action: result == true
              ? JsConfirmResponseAction.CONFIRM
              : JsConfirmResponseAction.CANCEL,
        );
      },
    );
  }

  static Color? _parseHexColor(String hex) {
    var s = hex.replaceAll('#', '');
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final value = int.tryParse(s, radix: 16);
    if (value == null) return null;
    return Color(value);
  }
}
