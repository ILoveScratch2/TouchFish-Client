// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sticker_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$myStickerPacksHash() => r'7db3690ff6930d6fa2062ad82064a2525f74c26d';

/// 用户拥有的 Sticker 包
///
/// Copied from [MyStickerPacks].
@ProviderFor(MyStickerPacks)
final myStickerPacksProvider =
    AutoDisposeAsyncNotifierProvider<
      MyStickerPacks,
      List<OwnedStickerPack>
    >.internal(
      MyStickerPacks.new,
      name: r'myStickerPacksProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$myStickerPacksHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MyStickerPacks = AutoDisposeAsyncNotifier<List<OwnedStickerPack>>;
String _$recentStickersHash() => r'5e265be1bd78baf8a417bcd116e208d8e348ffcd';

/// 最近使用的 Sticker（本地持久化）
///
/// Copied from [RecentStickers].
@ProviderFor(RecentStickers)
final recentStickersProvider =
    AutoDisposeAsyncNotifierProvider<
      RecentStickers,
      List<RecentStickerItem>
    >.internal(
      RecentStickers.new,
      name: r'recentStickersProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recentStickersHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RecentStickers = AutoDisposeAsyncNotifier<List<RecentStickerItem>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
