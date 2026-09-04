import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/sticker_model.dart';
import '../../services/api/tf_api_client.dart';
import '../../services/auth_state.dart';

part 'sticker_provider.g.dart';

/// UserSticker.exe
@riverpod
class MyStickerPacks extends _$MyStickerPacks {
  @override
  Future<List<OwnedStickerPack>> build() async {
    // 当前账号
    void onAuthChanged() => ref.invalidateSelf();
    AuthState.instance.addListener(onAuthChanged);
    ref.onDispose(() => AuthState.instance.removeListener(onAuthChanged));

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;

    if (uid == null || password == null) {
      return [];
    }

    final packs = await TfApiClient.instance.getMyStickerPacks(
      uid,
      password,
    );

    packs.sort((a, b) => a.order.compareTo(b.order));
    return packs;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

/// RECENT STICKERS PLEASE
@riverpod
class RecentStickers extends _$RecentStickers {
  static const int _maxRecentItems = 30;
  static const String _storageKey = 'recent_stickers';

  @override
  Future<List<RecentStickerItem>> build() async {
    return _loadFromStorage();
  }

  /// 记录
  Future<void> recordUsage(StickerPack pack, StickerItem sticker) async {
    final item = RecentStickerItem(
      packId: pack.id,
      packPrefix: pack.prefix,
      stickerId: sticker.id,
      stickerSlug: sticker.slug,
      fileHash: sticker.fileHash,
      fileType: sticker.fileType,
      lastUsed: DateTime.now(),
    );

    List<RecentStickerItem> current;
    final currentState = state.valueOrNull;
    if (currentState != null) {
      current = currentState;
    } else {
      try {
        current = await future;
      } catch (_) {
        current = await _loadFromStorage();
      }
    }

    final newState = [
      item,
      ...current.where(
        (s) => s.packId != pack.id || s.stickerId != sticker.id,
      ),
    ].take(_maxRecentItems).toList();
    state = AsyncValue.data(newState);
    await _saveToStorage(newState);
  }

  Future<void> refresh() async {
    final items = await _loadFromStorage();
    state = AsyncValue.data(items);
  }

  Future<List<RecentStickerItem>> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        return jsonList
          .map((json) => RecentStickerItem.fromJson(json))
          .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveToStorage(List<RecentStickerItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = items.map((item) => item.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (_) {}
  }
}


class RecentStickerItem {
  final String packId;
  final String packPrefix;
  final String stickerId;
  final String stickerSlug;
  final String fileHash;
  final String fileType;
  final DateTime lastUsed;

  RecentStickerItem({
    required this.packId,
    required this.packPrefix,
    required this.stickerId,
    required this.stickerSlug,
    required this.fileHash,
    required this.fileType,
    required this.lastUsed,
  });

  String get textFormat => ':$packPrefix+$stickerSlug:';

  Map<String, dynamic> toJson() => {
    'packId': packId,
    'packPrefix': packPrefix,
    'stickerId': stickerId,
    'stickerSlug': stickerSlug,
    'fileHash': fileHash,
    'fileType': fileType,
    'lastUsed': lastUsed.toIso8601String(),
  };

  factory RecentStickerItem.fromJson(Map<String, dynamic> json) {
    return RecentStickerItem(
      packId: json['packId'] as String,
      packPrefix: json['packPrefix'] as String,
      stickerId: json['stickerId'] as String,
      stickerSlug: json['stickerSlug'] as String,
      fileHash: json['fileHash'] as String,
      fileType: json['fileType'] as String,
      lastUsed: DateTime.parse(json['lastUsed'] as String),
    );
  }
}
