import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:file_picker/file_picker.dart';

import '../l10n/app_localizations.dart';
import '../models/sticker_model.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../widgets/stickers/sticker_image.dart';


class StickerMarketplaceScreen extends StatefulWidget {
  const StickerMarketplaceScreen({super.key});
  @override
  State<StickerMarketplaceScreen> createState() => _StickerMarketplaceScreenState();
}

class _StickerMarketplaceScreenState extends State<StickerMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  Timer? _debounce;
  List<StickerPack> _market = const [];
  List<OwnedStickerPack> _owned = const [];
  bool _loading = true;
  String _order = 'usage';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    try {
      final market = await TfApiClient.instance.getStickerMarket(
        query: _search.text.trim(),
        order: _order,
      );
      final owned = uid != null && password != null
          ? await TfApiClient.instance.getMyStickerPacks(uid, password)
          : <OwnedStickerPack>[];
      if (!mounted) return;
      setState(() {
        _market = (market['items'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => StickerPack.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        _owned = owned;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setOwned(StickerPack pack, bool owned) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    await TfApiClient.instance.setStickerOwnership(uid, password, pack.id, owned);
    await _load();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stickerMarketTitle),
        actions: [
          IconButton(
            tooltip: _order == 'usage'
                ? l10n.stickerSortByDate
                : l10n.stickerSortByUsage,
            icon: Icon(_order == 'usage'
                ? Symbols.local_fire_department
                : Symbols.schedule),
            onPressed: () {
              setState(() => _order = _order == 'usage' ? 'date' : 'usage');
              _load();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.stickerMarketTab),
            Tab(text: l10n.stickerOwnedTab),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _search,
              hintText: l10n.stickerSearchHint,
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Symbols.search),
              ),
              trailing: <Widget>[
                if (_search.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Symbols.close),
                    onPressed: () {
                      _search.clear();
                      _load();
                    },
                  ),
              ],
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _buildMarketTab(cs, l10n),
                      _buildOwnedTab(cs, l10n),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketTab(ColorScheme cs, AppLocalizations l10n) {
    if (_market.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [SizedBox.shrink()]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _market.length,
        itemBuilder: (_, index) {
          final pack = _market[index];
          final isOwned = _owned.any((item) => item.packId == pack.id);
          return _MarketplacePackCard(
            pack: pack,
            isOwned: isOwned,
            onToggle: () => _setOwned(pack, !isOwned),
          );
        },
      ),
    );
  }

  Widget _buildOwnedTab(ColorScheme cs, AppLocalizations l10n) {
    if (_owned.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [SizedBox.shrink()]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _owned.length,
        onReorder: (oldIndex, newIndex) async {
          if (newIndex > oldIndex) newIndex--;
          final reordered = [..._owned];
          final item = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, item);
          setState(() => _owned = reordered);
          final uid = AuthState.instance.uid;
          final password = AuthState.instance.password;
          if (uid != null && password != null) {
            final ok = await TfApiClient.instance.reorderStickerOwnership(
              uid,
              password,
              reordered.map((e) => e.packId).toList(),
            );
            if (!ok) await _load();
          }
        },
        proxyDecorator: (child, _, __) => Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
        itemBuilder: (_, index) {
          final item = _owned[index];
          return _OwnedPackCard(
            key: ValueKey(item.packId),
            pack: item.pack,
            onRemove: () => _setOwned(item.pack, false),
          );
        },
      ),
    );
  }
}


class _MarketplacePackCard extends StatelessWidget {
  final StickerPack pack;
  final bool isOwned;
  final VoidCallback onToggle;

  const _MarketplacePackCard({
    required this.pack,
    required this.isOwned,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    const previewCount = 4;
    final previews = pack.stickers.take(previewCount).toList();

    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (previews.isNotEmpty)
            Container(
              color: cs.surfaceContainerHigh,
              padding: const EdgeInsets.all(12),
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: previewCount,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  if (index < previews.length) {
                    final sticker = previews[index];
                    return AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: cs.surfaceContainerLow,
                          child: StickerImage(
                            hash: sticker.fileHash,
                            fileType: sticker.fileType,
                            error: Icon(Icons.broken_image,
                                size: 24, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                    );
                  }
                  return AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ColoredBox(
                        color: cs.surfaceContainerLow,
                        child: Center(
                          child: Icon(Symbols.sticky_note_2,
                              size: 20,
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          // Info row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                // Pack icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: ColoredBox(
                      color: cs.surfaceContainerLow,
                      child: pack.iconHash != null
                          ? StickerImage(
                              hash: pack.iconHash!,
                              fileType: 'unknown',
                              error: Icon(Symbols.sticky_note_2,
                                  color: cs.onSurfaceVariant),
                            )
                          : Icon(Symbols.sticky_note_2,
                              color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pack.name,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pack.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          pack.description,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: onToggle,
                  icon: Icon(
                    isOwned ? Symbols.remove_circle : Symbols.add_circle,
                    size: 18,
                  ),
                  label: Text(isOwned
                      ? l10n.stickerRemovePack
                      : l10n.stickerAddPack),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnedPackCard extends StatefulWidget {
  final StickerPack pack;
  final VoidCallback onRemove;

  const _OwnedPackCard({
    super.key,
    required this.pack,
    required this.onRemove,
  });

  @override
  State<_OwnedPackCard> createState() => _OwnedPackCardState();
}

class _OwnedPackCardState extends State<_OwnedPackCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Card.filled(
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Symbols.drag_indicator, color: cs.onSurfaceVariant),
            title: Text(widget.pack.name,
                style: Theme.of(context).textTheme.titleSmall),
            subtitle: widget.pack.description.isNotEmpty
                ? Text(
                    widget.pack.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_expanded
                      ? Symbols.keyboard_arrow_up
                      : Symbols.keyboard_arrow_down),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
                IconButton(
                  tooltip: l10n.stickerRemovePack,
                  icon: Icon(Symbols.delete_outline, color: cs.error),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ),
          if (_expanded && widget.pack.stickers.isNotEmpty)
            SizedBox(
              height: 64,
              child: ListView.separated(
                padding:
                    const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                scrollDirection: Axis.horizontal,
                itemCount: widget.pack.stickers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final sticker = widget.pack.stickers[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 52,
                      child: ColoredBox(
                        color: cs.surfaceContainerLow,
                        child: StickerImage(
                          hash: sticker.fileHash,
                          fileType: sticker.fileType,
                          error: Icon(Icons.broken_image,
                              size: 20, color: cs.onSurfaceVariant),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}


class MyStickerPacksScreen extends StatefulWidget {
  const MyStickerPacksScreen({super.key});
  @override
  State<MyStickerPacksScreen> createState() => _MyStickerPacksScreenState();
}

class _MyStickerPacksScreenState extends State<MyStickerPacksScreen> {
  List<StickerPack> _packs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    setState(() => _loading = true);
    try {
      final result =
          await TfApiClient.instance.getCreatedStickerPacks(uid, password);
      if (mounted) setState(() { _packs = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
    final name = TextEditingController();
    final prefix = TextEditingController();
    final description = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.stickerCreatePack),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: l10n.stickerPackName),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: prefix,
              decoration: InputDecoration(
                labelText: l10n.stickerPackPrefix,
                helperText: 'Only letters, digits, _ and -',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              decoration:
                  InputDecoration(labelText: l10n.stickerPackDescription),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.stickerPackCreate),
          ),
        ],
      ),
    );
    final nameText = name.text.trim();
    final prefixText = prefix.text.trim();
    final descriptionText = description.text.trim();
    name.dispose();
    prefix.dispose();
    description.dispose();
    if (accepted != true) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    await TfApiClient.instance.createStickerPack(
      uid,
      password,
      name: nameText,
      prefix: prefixText,
      description: descriptionText,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stickerMyPacks)),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Symbols.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _packs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.sticky_note_2,
                          size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        l10n.stickerNoPacks,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _create,
                        icon: const Icon(Symbols.add, size: 18),
                        label: Text(l10n.stickerCreatePack),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _packs.length,
                    itemBuilder: (_, index) {
                      final pack = _packs[index];
                      final stickerCount = pack.stickers.length;
                      return Card.filled(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: cs.surfaceContainer,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: ColoredBox(
                                color: cs.surfaceContainerLow,
                                child: pack.iconHash != null
                                    ? StickerImage(
                                        hash: pack.iconHash!,
                                        fileType: 'unknown',
                                      )
                                    : Icon(Symbols.sticky_note_2,
                                        color: cs.onSurfaceVariant),
                              ),
                            ),
                          ),
                          title: Text(pack.name,
                              style:
                                  Theme.of(context).textTheme.titleSmall),
                          subtitle: Text(
                            '$stickerCount stickers  :${pack.prefix}:',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          trailing: const Icon(Symbols.chevron_right),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    StickerPackEditorScreen(pack: pack),
                              ),
                            );
                            _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class StickerPackEditorScreen extends StatefulWidget {
  final StickerPack pack;
  const StickerPackEditorScreen({super.key, required this.pack});
  @override
  State<StickerPackEditorScreen> createState() =>
      _StickerPackEditorScreenState();
}

class _StickerPackEditorScreenState extends State<StickerPackEditorScreen> {
  late StickerPack _pack;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pack = widget.pack;
  }

  Future<void> _refresh() async {
    final pack = await TfApiClient.instance.getStickerPack(_pack.id);
    if (pack != null && mounted) setState(() => _pack = pack);
  }

  Future<void> _addSticker() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'png',
        'jpg',
        'jpeg',
        'gif',
        'bmp',
        'svg',
        'tgs'
      ],
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final l10n = AppLocalizations.of(context)!;
    final slug = TextEditingController(
      text: file.name
          .split('.')
          .first
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-'),
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.stickerAddSticker),
        content: TextField(
          controller: slug,
          decoration: InputDecoration(labelText: l10n.stickerSlugLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.stickerAdd),
          ),
        ],
      ),
    );
    final slugText = slug.text.trim();
    slug.dispose();
    if (accepted != true || slugText.isEmpty) return;
    setState(() => _busy = true);
    try {
      final uploaded = await TfApiClient.instance.uploadFile(
        uid,
        password,
        file.name,
        base64Encode(bytes),
      );
      final hash = uploaded?['hash']?.toString();
      if (hash != null) {
        await TfApiClient.instance.createStickerItem(
          uid,
          password,
          packId: _pack.id,
          slug: slugText,
          fileHash: hash,
        );
      }
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(StickerItem sticker) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    await TfApiClient.instance.deleteStickerItem(
      uid,
      password,
      _pack.id,
      sticker.id,
    );
    await _refresh();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final items = [..._pack.stickers];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    setState(() => _pack = StickerPack(
          id: _pack.id,
          creatorUid: _pack.creatorUid,
          name: _pack.name,
          description: _pack.description,
          prefix: _pack.prefix,
          iconHash: _pack.iconHash,
          usageCount: _pack.usageCount,
          stickers: items,
        ));
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid != null && password != null) {
      await TfApiClient.instance.reorderStickerItems(
        uid,
        password,
        _pack.id,
        items.map((e) => e.id).toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_pack.name),
        actions: [
          IconButton(
            tooltip: l10n.stickerDeletePack,
            icon: Icon(Symbols.delete_outline, color: cs.error),
            onPressed: () async {
              final uid = AuthState.instance.uid;
              final password = AuthState.instance.password;
              if (uid != null &&
                  password != null &&
                  await TfApiClient.instance.deleteStickerPack(
                    uid,
                    password,
                    _pack.id,
                  ) &&
                  mounted) {
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : _addSticker,
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Symbols.add),
      ),
      body: Column(
        children: [
          // Meta card
          Card.filled(
            margin: const EdgeInsets.all(16),
            color: cs.surfaceContainer,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: ColoredBox(
                        color: cs.surfaceContainerLow,
                        child: _pack.iconHash != null
                            ? StickerImage(
                                hash: _pack.iconHash!,
                                fileType: 'unknown',
                              )
                            : Icon(Symbols.sticky_note_2,
                                color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_pack.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        if (_pack.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _pack.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Chip(
                          avatar: const Icon(Symbols.tag, size: 16),
                          label: Text(':${_pack.prefix}+'),
                          backgroundColor: cs.surfaceContainerHigh,
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sticker count header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '${_pack.stickers.length} ${l10n.stickerMyPacks}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Sticker list
          Expanded(
            child: _pack.stickers.isEmpty
                ? Center(
                    child: Text(
                      l10n.stickerNoPacks,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: _pack.stickers.length,
                    onReorder: _reorder,
                    proxyDecorator: (child, _, __) => Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: child,
                    ),
                    itemBuilder: (context, index) {
                      final sticker = _pack.stickers[index];
                      return Card.outlined(
                        key: ValueKey(sticker.id),
                        margin: const EdgeInsets.only(bottom: 8),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: ColoredBox(
                                color: cs.surfaceContainerLow,
                                child: StickerImage(
                                  hash: sticker.fileHash,
                                  fileType: sticker.fileType,
                                  error: Icon(
                                    Icons.broken_image,
                                    size: 24,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            sticker.name?.isNotEmpty == true
                                ? sticker.name!
                                : sticker.slug,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          subtitle: Text(
                            ':${_pack.prefix}+${sticker.slug}:',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          trailing: IconButton(
                            icon: Icon(Symbols.close, color: cs.error),
                            onPressed: () => _delete(sticker),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
