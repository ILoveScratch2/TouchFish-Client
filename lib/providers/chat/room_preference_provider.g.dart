// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_preference_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pinnedRoomIdsHash() => r'8d8a9ddb50b13e490ace81fe065d8f436d507b03';

/// 所有聊天室
///
/// Copied from [pinnedRoomIds].
@ProviderFor(pinnedRoomIds)
final pinnedRoomIdsProvider = AutoDisposeProvider<List<String>>.internal(
  pinnedRoomIds,
  name: r'pinnedRoomIdsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pinnedRoomIdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PinnedRoomIdsRef = AutoDisposeProviderRef<List<String>>;
String _$isRoomPinnedHash() => r'ccd1122d66e4bd312496107ad2d9415cf8c18fa8';

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

/// See also [isRoomPinned].
@ProviderFor(isRoomPinned)
const isRoomPinnedProvider = IsRoomPinnedFamily();

/// See also [isRoomPinned].
class IsRoomPinnedFamily extends Family<bool> {
  /// See also [isRoomPinned].
  const IsRoomPinnedFamily();

  /// See also [isRoomPinned].
  IsRoomPinnedProvider call(String roomId) {
    return IsRoomPinnedProvider(roomId);
  }

  @override
  IsRoomPinnedProvider getProviderOverride(
    covariant IsRoomPinnedProvider provider,
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
  String? get name => r'isRoomPinnedProvider';
}

/// See also [isRoomPinned].
class IsRoomPinnedProvider extends AutoDisposeProvider<bool> {
  /// See also [isRoomPinned].
  IsRoomPinnedProvider(String roomId)
    : this._internal(
        (ref) => isRoomPinned(ref as IsRoomPinnedRef, roomId),
        from: isRoomPinnedProvider,
        name: r'isRoomPinnedProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$isRoomPinnedHash,
        dependencies: IsRoomPinnedFamily._dependencies,
        allTransitiveDependencies:
            IsRoomPinnedFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  IsRoomPinnedProvider._internal(
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
  Override overrideWith(bool Function(IsRoomPinnedRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: IsRoomPinnedProvider._internal(
        (ref) => create(ref as IsRoomPinnedRef),
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
  AutoDisposeProviderElement<bool> createElement() {
    return _IsRoomPinnedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsRoomPinnedProvider && other.roomId == roomId;
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
mixin IsRoomPinnedRef on AutoDisposeProviderRef<bool> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _IsRoomPinnedProviderElement extends AutoDisposeProviderElement<bool>
    with IsRoomPinnedRef {
  _IsRoomPinnedProviderElement(super.provider);

  @override
  String get roomId => (origin as IsRoomPinnedProvider).roomId;
}

String _$roomPreferenceControllerHash() =>
    r'4d97237c6024b413cda0eb41956a46ae49d94ac5';

abstract class _$RoomPreferenceController
    extends BuildlessAutoDisposeNotifier<ChatRoomPreference> {
  late final String roomId;

  ChatRoomPreference build(String roomId);
}

/// 聊天室偏好
///
/// Copied from [RoomPreferenceController].
@ProviderFor(RoomPreferenceController)
const roomPreferenceControllerProvider = RoomPreferenceControllerFamily();

/// 聊天室偏好
///
/// Copied from [RoomPreferenceController].
class RoomPreferenceControllerFamily extends Family<ChatRoomPreference> {
  /// 聊天室偏好
  ///
  /// Copied from [RoomPreferenceController].
  const RoomPreferenceControllerFamily();

  /// 聊天室偏好
  ///
  /// Copied from [RoomPreferenceController].
  RoomPreferenceControllerProvider call(String roomId) {
    return RoomPreferenceControllerProvider(roomId);
  }

  @override
  RoomPreferenceControllerProvider getProviderOverride(
    covariant RoomPreferenceControllerProvider provider,
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
  String? get name => r'roomPreferenceControllerProvider';
}

/// 聊天室偏好
///
/// Copied from [RoomPreferenceController].
class RoomPreferenceControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<
          RoomPreferenceController,
          ChatRoomPreference
        > {
  /// 聊天室偏好
  ///
  /// Copied from [RoomPreferenceController].
  RoomPreferenceControllerProvider(String roomId)
    : this._internal(
        () => RoomPreferenceController()..roomId = roomId,
        from: roomPreferenceControllerProvider,
        name: r'roomPreferenceControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$roomPreferenceControllerHash,
        dependencies: RoomPreferenceControllerFamily._dependencies,
        allTransitiveDependencies:
            RoomPreferenceControllerFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  RoomPreferenceControllerProvider._internal(
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
  ChatRoomPreference runNotifierBuild(
    covariant RoomPreferenceController notifier,
  ) {
    return notifier.build(roomId);
  }

  @override
  Override overrideWith(RoomPreferenceController Function() create) {
    return ProviderOverride(
      origin: this,
      override: RoomPreferenceControllerProvider._internal(
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
  AutoDisposeNotifierProviderElement<
    RoomPreferenceController,
    ChatRoomPreference
  >
  createElement() {
    return _RoomPreferenceControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RoomPreferenceControllerProvider && other.roomId == roomId;
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
mixin RoomPreferenceControllerRef
    on AutoDisposeNotifierProviderRef<ChatRoomPreference> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _RoomPreferenceControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          RoomPreferenceController,
          ChatRoomPreference
        >
    with RoomPreferenceControllerRef {
  _RoomPreferenceControllerProviderElement(super.provider);

  @override
  String get roomId => (origin as RoomPreferenceControllerProvider).roomId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
