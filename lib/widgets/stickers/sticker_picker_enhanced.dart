import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/sticker_model.dart';
import '../../providers/sticker/sticker_provider.dart';
import '../../routes/app_routes.dart';
import 'sticker_image.dart';

/// 高级安全 Windows Defender 贴图选择器（来不及介入了）
class StickerPickerEnhanced extends ConsumerStatefulWidget {
  final void Function(StickerPack pack, StickerItem sticker) onPick;

  const StickerPickerEnhanced({super.key, required this.onPick});

  @override
  ConsumerState<StickerPickerEnhanced> createState() =>
      _StickerPickerEnhancedState();
}

class _StickerPickerEnhancedState
    extends ConsumerState<StickerPickerEnhanced>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPackIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final packsAsync = ref.watch(myStickerPacksProvider);
    final recentAsync = ref.watch(recentStickersProvider);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.history), text: l10n.stickerRecent),
            Tab(
              icon: const Icon(Icons.emoji_emotions),
              text: l10n.stickerPacks,
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              recentAsync.when(
                data: _buildRecentTab,
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (_, _) => _buildLoadError(
                  onRetry: () =>
                      ref.read(recentStickersProvider.notifier).refresh(),
                ),
              ),
              packsAsync.when(
                data: _buildPacksTab,
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (_, _) => _buildLoadError(
                  onRetry: () =>
                      ref.read(myStickerPacksProvider.notifier).refresh(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadError({required VoidCallback onRetry}) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(l10n.stickerLoadError),
      ),
    );
  }

  // ---------- 最近使用 ----------

  Widget _buildRecentTab(List<RecentStickerItem> recent) {
    final l10n = AppLocalizations.of(context)!;
    if (recent.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.stickerNoRecentStickers,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: recent.length,
      itemBuilder: (context, index) {
        final item = recent[index];
        return InkWell(
          key: ValueKey('recent-${item.packId}-${item.stickerId}'),
          onTap: () => _useRecent(item),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: StickerImage(
              hash: item.fileHash,
              fileType: item.fileType,
            ),
          ),
        );
      },
    );
  }

  /// 最近使用项没有缓存 pack/sticker
  Future<void> _useRecent(RecentStickerItem item) async {
    final packs = await _resolveOwnedPacks();
    if (!mounted) return;

    for (final owned in packs) {
      if (owned.pack.prefix != item.packPrefix) continue;
      for (final sticker in owned.pack.stickers) {
        if (sticker.slug == item.stickerSlug) {
          _pick(owned.pack, sticker);
          return;
        }
      }
    }
  }

  Future<List<OwnedStickerPack>> _resolveOwnedPacks() async {
    final value = ref.read(myStickerPacksProvider).valueOrNull;
    if (value != null) return value;
    try {
      return await ref.read(myStickerPacksProvider.future);
    } catch (_) {
      return const [];
    }
  }

  // ---------- 我的表情包 ----------

  Widget _buildPacksTab(List<OwnedStickerPack> packs) {
    final l10n = AppLocalizations.of(context)!;
    if (packs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_emotions_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.stickerNoPacks,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _openMarket,
              icon: const Icon(Icons.storefront_outlined),
              label: Text(l10n.stickerBrowseMarket),
            ),
          ],
        ),
      );
    }

    final effectiveIndex =
        _selectedPackIndex.clamp(0, packs.length - 1);

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: packs.length,
            itemBuilder: (context, index) {
              final pack = packs[index].pack;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey('pack-${pack.id}'),
                  selected: index == effectiveIndex,
                  label: Text(
                    pack.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  avatar: _buildPackIcon(pack),
                  onSelected: (_) =>
                      setState(() => _selectedPackIndex = index),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildStickerGrid(packs[effectiveIndex].pack)),
      ],
    );
  }

  Widget _buildPackIcon(StickerPack pack) {
    final iconHash =
        pack.iconHash ?? (pack.stickers.isNotEmpty ? pack.stickers.first.fileHash : null);
    if (iconHash == null) {
      return const Icon(Icons.sticky_note_2_outlined, size: 20);
    }
    return SizedBox(
      width: 20,
      height: 20,
      child: StickerImage(hash: iconHash, fileType: 'unknown'),
    );
  }

  Widget _buildStickerGrid(StickerPack pack) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: pack.stickers.length,
      itemBuilder: (context, index) {
        final sticker = pack.stickers[index];
        return StickerTile(
          key: ValueKey('sticker-${sticker.id}'),
          sticker: sticker,
          onTap: () => _pick(pack, sticker),
        );
      },
    );
  }

  void _pick(StickerPack pack, StickerItem sticker) {
    widget.onPick(pack, sticker);
    ref
        .read(recentStickersProvider.notifier)
        .recordUsage(pack, sticker);
  }

  void _openMarket() {
    context.push(AppRoutes.stickerMarket);
  }
}
