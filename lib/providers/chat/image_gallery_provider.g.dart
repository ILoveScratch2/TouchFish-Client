// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_gallery_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$imageGalleryHash() => r'ebd538cabbd4e9e8a6b9a5785769e4ea631bf61d';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$ImageGallery
    extends BuildlessAutoDisposeNotifier<ImageGalleryState> {
  late final String roomId;

  ImageGalleryState build(String roomId);
}

/// 图片画廊
///
/// Copied from [ImageGallery].
@ProviderFor(ImageGallery)
const imageGalleryProvider = ImageGalleryFamily();

/// 图片画廊
///
/// Copied from [ImageGallery].
class ImageGalleryFamily extends Family<ImageGalleryState> {
  /// 图片画廊
  ///
  /// Copied from [ImageGallery].
  const ImageGalleryFamily();

  /// 图片画廊
  ///
  /// Copied from [ImageGallery].
  ImageGalleryProvider call(String roomId) {
    return ImageGalleryProvider(roomId);
  }

  @override
  ImageGalleryProvider getProviderOverride(
    covariant ImageGalleryProvider provider,
  ) {
    return call(provider.roomId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'imageGalleryProvider';
}

/// 图片画廊
///
/// Copied from [ImageGallery].
class ImageGalleryProvider
    extends AutoDisposeNotifierProviderImpl<ImageGallery, ImageGalleryState> {
  /// 图片画廊
  ///
  /// Copied from [ImageGallery].
  ImageGalleryProvider(String roomId)
    : this._internal(
        () => ImageGallery()..roomId = roomId,
        from: imageGalleryProvider,
        name: r'imageGalleryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$imageGalleryHash,
        dependencies: ImageGalleryFamily._dependencies,
        allTransitiveDependencies:
            ImageGalleryFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  ImageGalleryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.roomId,
  }) : super.internal();

  final String roomId;

  @override
  ImageGalleryState runNotifierBuild(covariant ImageGallery notifier) {
    return notifier.build(roomId);
  }

  @override
  Override overrideWith(ImageGallery Function() create) {
    return ProviderOverride(
      origin: this,
      override: ImageGalleryProvider._internal(
        () => create()..roomId = roomId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        roomId: roomId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ImageGallery, ImageGalleryState>
  createElement() {
    return _ImageGalleryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ImageGalleryProvider && other.roomId == roomId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, roomId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ImageGalleryRef on AutoDisposeNotifierProviderRef<ImageGalleryState> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _ImageGalleryProviderElement
    extends AutoDisposeNotifierProviderElement<ImageGallery, ImageGalleryState>
    with ImageGalleryRef {
  _ImageGalleryProviderElement(super.provider);

  @override
  String get roomId => (origin as ImageGalleryProvider).roomId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
