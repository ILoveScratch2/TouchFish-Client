import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/sticker_model.dart';
import '../../services/api/tf_api_client.dart';
import '../../services/auth_state.dart';
import 'sticker_image.dart';

class StickerPickerPanel extends StatefulWidget {
  final void Function(StickerPack pack, StickerItem sticker) onPick;
  final void Function(StickerPack pack, StickerItem sticker)? onLongPress;
  const StickerPickerPanel({super.key, required this.onPick, this.onLongPress});
  @override
  State<StickerPickerPanel> createState() => _StickerPickerPanelState();
}

class _StickerPickerPanelState extends State<StickerPickerPanel> {
  List<OwnedStickerPack> packs = const [];
  int selected = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      final result = await TfApiClient.instance.getMyStickerPacks(uid, password);
      if (mounted) {
        setState(() {
          packs = result..sort((a, b) => a.order.compareTo(b.order));
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (packs.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(AppLocalizations.of(context)!.stickerNoPacks),
        ),
      );
    }
    selected = selected.clamp(0, packs.length - 1);
    final pack = packs[selected].pack;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            scrollDirection: Axis.horizontal,
            itemCount: packs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (_, index) {
              final candidate = packs[index].pack;
              final image = candidate.iconHash ??
                  (candidate.stickers.isEmpty
                      ? null
                      : candidate.stickers.first.fileHash);
              return ChoiceChip(
                selected: selected == index,
                showCheckmark: false,
                avatar: image == null
                    ? const Icon(Icons.sticky_note_2_outlined, size: 18)
                    : SizedBox(
                        width: 18,
                        height: 18,
                        child: StickerImage(hash: image, fileType: 'unknown'),
                      ),
                label: Text(
                  candidate.name.length > 8
                      ? '${candidate.name.substring(0, 8)}...'
                      : candidate.name,
                ),
                onSelected: (_) => setState(() => selected = index),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 56,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: pack.stickers.length,
            itemBuilder: (_, index) {
              final sticker = pack.stickers[index];
              return StickerTile(
                sticker: sticker,
                onTap: () => widget.onPick(pack, sticker),
                onLongPress: widget.onLongPress == null
                    ? null
                    : () => widget.onLongPress!(pack, sticker),
              );
            },
          ),
        ),
      ],
    );
  }
}
