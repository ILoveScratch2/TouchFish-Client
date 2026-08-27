import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/browser_storage.dart';

enum BrowserListMode { history, bookmarks }

class BrowserListScreen extends StatefulWidget {
  final BrowserListMode mode;

  const BrowserListScreen({super.key, this.mode = BrowserListMode.history});

  @override
  State<BrowserListScreen> createState() => _BrowserListScreenState();
}

class _BrowserListScreenState extends State<BrowserListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  List<Map<String, dynamic>> _entries = const [];
  bool _searching = false;

  bool get _isHistory => widget.mode == BrowserListMode.history;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final storage = BrowserStorage.instance;
    final entries = _isHistory
        ? await storage.getHistory()
        : await storage.getBookmarks();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }

  List<Map<String, dynamic>> _visibleEntries() {
    if (_query.isEmpty) return _entries;
    return _entries.where((e) {
      final title = ((e['title'] ?? '') as String).toLowerCase();
      final url = ((e['url'] ?? '') as String).toLowerCase();
      return title.contains(_query) || url.contains(_query);
    }).toList();
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final url = (entry['url'] ?? '') as String;
    final storage = BrowserStorage.instance;
    if (_isHistory) {
      await storage.removeHistoryEntry(url);
    } else {
      await storage.removeBookmark(url);
    }
    if (!mounted) return;
    setState(() => _entries = List.of(_entries)..removeWhere((e) => e['url'] == url));
    if (!_isHistory) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.browserBookmarkRemoved)),
      );
    }
  }

  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.browserHistoryClear),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.browserClearDataConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await BrowserStorage.instance.clearHistoryBefore(null);
    if (!mounted) return;
    setState(() => _entries = const []);
  }

  /// 按日分组标题
  String _sectionTitle(AppLocalizations l10n, DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return l10n.browserHistoryToday;
    if (diff == 1) return l10n.browserHistoryYesterday;
    return DateFormat('y/M/d').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _visibleEntries();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isHistory ? l10n.browserHistory : l10n.browserBookmarks),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: l10n.browserFindOnPage,
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _searchController.clear();
                _query = '';
              }
            }),
          ),
          if (_isHistory)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: l10n.browserHistoryClear,
              onPressed: entries.isEmpty ? null : _clearHistory,
            ),
        ],
        bottom: _searching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _isHistory
                          ? l10n.browserHistorySearchHint
                          : l10n.browserBookmarksSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: entries.isEmpty
          ? _buildEmptyState(context, l10n)
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final url = (entry['url'] ?? '') as String;
                final title = (entry['title'] ?? url) as String;
                final isSectionHeader =
                    _isHistory && (index == 0 || _isNewDay(entries[index - 1], entry));
                final time = _isHistory ? (entry['visitedAt'] as int? ?? 0) : null;

                if (isSectionHeader) {
                  final day = DateTime.fromMillisecondsSinceEpoch(time!);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      _sectionTitle(l10n, day),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                return ListTile(
                  leading: _FaviconAvatar(title: title, url: url),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    tooltip: l10n.browserDeleteEntry,
                    onPressed: () => _deleteEntry(entry),
                  ),
                  onTap: () => Navigator.of(context).pop(url),
                );
              },
            ),
    );
  }

  bool _isNewDay(Map<String, dynamic> prev, Map<String, dynamic> current) {
    final prevTime = DateTime.fromMillisecondsSinceEpoch(
      (prev['visitedAt'] as int? ?? 0),
    );
    final curTime = DateTime.fromMillisecondsSinceEpoch(
      (current['visitedAt'] as int? ?? 0),
    );
    return DateTime(prevTime.year, prevTime.month, prevTime.day) !=
        DateTime(curTime.year, curTime.month, curTime.day);
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final icon = _query.isNotEmpty
        ? Icons.search_off_rounded
        : (_isHistory ? Icons.history_rounded : Icons.bookmarks_rounded);
    final text = _query.isNotEmpty
        ? l10n.browserNoSearchResults
        : (_isHistory ? l10n.browserHistoryEmpty : l10n.browserBookmarksEmpty);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 首字母圆形占位图标
/// favicon 是什么？我不知道呀
class _FaviconAvatar extends StatelessWidget {
  final String title;
  final String url;

  const _FaviconAvatar({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host ?? '';
    final letter = (title.isNotEmpty ? title[0] : (host.isNotEmpty ? host[0] : '?'))
        .toUpperCase();
    final palette = Colors.primaries;
    final color = palette[host.hashCode.abs() % palette.length].shade600;
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Text(
        letter,
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}
