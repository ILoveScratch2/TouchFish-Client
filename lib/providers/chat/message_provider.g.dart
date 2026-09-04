// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$unreadCountHash() => r'3a528998313675ff66af1d91ba5692c0f1ebb2d5';

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

/// 房间未读消息数（来自 ChatDataService 房间列表的服务端角标语义：
/// 在聊天列表收到新消息时累计、进入房间时清零）。
///
/// 不要用 `messages.where((m) => !m.isMe).length` 推导——那是对方消息总数，
/// 不等于未读数。CDS 是唯一真相源，这里只做透传。
///
/// Copied from [unreadCount].
@ProviderFor(unreadCount)
const unreadCountProvider = UnreadCountFamily();

/// 房间未读消息数（来自 ChatDataService 房间列表的服务端角标语义：
/// 在聊天列表收到新消息时累计、进入房间时清零）。
///
/// 不要用 `messages.where((m) => !m.isMe).length` 推导——那是对方消息总数，
/// 不等于未读数。CDS 是唯一真相源，这里只做透传。
///
/// Copied from [unreadCount].
class UnreadCountFamily extends Family<int> {
  /// 房间未读消息数（来自 ChatDataService 房间列表的服务端角标语义：
  /// 在聊天列表收到新消息时累计、进入房间时清零）。
  ///
  /// 不要用 `messages.where((m) => !m.isMe).length` 推导——那是对方消息总数，
  /// 不等于未读数。CDS 是唯一真相源，这里只做透传。
  ///
  /// Copied from [unreadCount].
  const UnreadCountFamily();

  /// 房间未读消息数（来自 ChatDataService 房间列表的服务端角标语义：
  /// 在聊天列表收到新消息时累计、进入房间时清零）。
  ///
  /// 不要用 `messages.where((m) => !m.isMe).length` 推导——那是对方消息总数，
  /// 不等于未读数。CDS 是唯一真相源，这里只做透传。
  ///
  /// Copied from [unreadCount].
  UnreadCountProvider call(String roomId) {
    return UnreadCountProvider(roomId);
  }

  @override
  UnreadCountProvider getProviderOverride(
    covariant UnreadCountProvider provider,
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
  String? get name => r'unreadCountProvider';
}

/// 房间未读消息数（来自 ChatDataService 房间列表的服务端角标语义：
/// 在聊天列表收到新消息时累计、进入房间时清零）。
///
/// 不要用 `messages.where((m) => !m.isMe).length` 推导——那是对方消息总数，
/// 不等于未读数。CDS 是唯一真相源，这里只做透传。
///
/// Copied from [unreadCount].
class UnreadCountProvider extends AutoDisposeProvider<int> {
  /// 房间未读消息数（来自 ChatDataService 房间列表的服务端角标语义：
  /// 在聊天列表收到新消息时累计、进入房间时清零）。
  ///
  /// 不要用 `messages.where((m) => !m.isMe).length` 推导——那是对方消息总数，
  /// 不等于未读数。CDS 是唯一真相源，这里只做透传。
  ///
  /// Copied from [unreadCount].
  UnreadCountProvider(String roomId)
    : this._internal(
        (ref) => unreadCount(ref as UnreadCountRef, roomId),
        from: unreadCountProvider,
        name: r'unreadCountProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$unreadCountHash,
        dependencies: UnreadCountFamily._dependencies,
        allTransitiveDependencies: UnreadCountFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  UnreadCountProvider._internal(
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
  Override overrideWith(int Function(UnreadCountRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: UnreadCountProvider._internal(
        (ref) => create(ref as UnreadCountRef),
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
  AutoDisposeProviderElement<int> createElement() {
    return _UnreadCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UnreadCountProvider && other.roomId == roomId;
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
mixin UnreadCountRef on AutoDisposeProviderRef<int> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _UnreadCountProviderElement extends AutoDisposeProviderElement<int>
    with UnreadCountRef {
  _UnreadCountProviderElement(super.provider);

  @override
  String get roomId => (origin as UnreadCountProvider).roomId;
}

String _$imageMessagesHash() => r'f88442b146b09edbf89c29c47e9d079c0e7de77b';

/// See also [imageMessages].
@ProviderFor(imageMessages)
const imageMessagesProvider = ImageMessagesFamily();

/// See also [imageMessages].
class ImageMessagesFamily extends Family<List<ChatMessage>> {
  /// See also [imageMessages].
  const ImageMessagesFamily();

  /// See also [imageMessages].
  ImageMessagesProvider call(String roomId) {
    return ImageMessagesProvider(roomId);
  }

  @override
  ImageMessagesProvider getProviderOverride(
    covariant ImageMessagesProvider provider,
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
  String? get name => r'imageMessagesProvider';
}

/// See also [imageMessages].
class ImageMessagesProvider extends AutoDisposeProvider<List<ChatMessage>> {
  /// See also [imageMessages].
  ImageMessagesProvider(String roomId)
    : this._internal(
        (ref) => imageMessages(ref as ImageMessagesRef, roomId),
        from: imageMessagesProvider,
        name: r'imageMessagesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$imageMessagesHash,
        dependencies: ImageMessagesFamily._dependencies,
        allTransitiveDependencies:
            ImageMessagesFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  ImageMessagesProvider._internal(
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
  Override overrideWith(
    List<ChatMessage> Function(ImageMessagesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ImageMessagesProvider._internal(
        (ref) => create(ref as ImageMessagesRef),
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
  AutoDisposeProviderElement<List<ChatMessage>> createElement() {
    return _ImageMessagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ImageMessagesProvider && other.roomId == roomId;
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
mixin ImageMessagesRef on AutoDisposeProviderRef<List<ChatMessage>> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _ImageMessagesProviderElement
    extends AutoDisposeProviderElement<List<ChatMessage>>
    with ImageMessagesRef {
  _ImageMessagesProviderElement(super.provider);

  @override
  String get roomId => (origin as ImageMessagesProvider).roomId;
}

String _$roomMessagesHash() => r'd2a4baa24862ce68bdd4ae7077a3e2db60a361a1';

abstract class _$RoomMessages
    extends BuildlessAutoDisposeNotifier<List<ChatMessage>> {
  late final String roomId;

  List<ChatMessage> build(String roomId);
}

/// 单个房间的消息列表
///
/// Copied from [RoomMessages].
@ProviderFor(RoomMessages)
const roomMessagesProvider = RoomMessagesFamily();

/// 单个房间的消息列表
///
/// Copied from [RoomMessages].
class RoomMessagesFamily extends Family<List<ChatMessage>> {
  /// 单个房间的消息列表
  ///
  /// Copied from [RoomMessages].
  const RoomMessagesFamily();

  /// 单个房间的消息列表
  ///
  /// Copied from [RoomMessages].
  RoomMessagesProvider call(String roomId) {
    return RoomMessagesProvider(roomId);
  }

  @override
  RoomMessagesProvider getProviderOverride(
    covariant RoomMessagesProvider provider,
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
  String? get name => r'roomMessagesProvider';
}

/// 单个房间的消息列表
///
/// Copied from [RoomMessages].
class RoomMessagesProvider
    extends AutoDisposeNotifierProviderImpl<RoomMessages, List<ChatMessage>> {
  /// 单个房间的消息列表
  ///
  /// Copied from [RoomMessages].
  RoomMessagesProvider(String roomId)
    : this._internal(
        () => RoomMessages()..roomId = roomId,
        from: roomMessagesProvider,
        name: r'roomMessagesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$roomMessagesHash,
        dependencies: RoomMessagesFamily._dependencies,
        allTransitiveDependencies:
            RoomMessagesFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  RoomMessagesProvider._internal(
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
  List<ChatMessage> runNotifierBuild(covariant RoomMessages notifier) {
    return notifier.build(roomId);
  }

  @override
  Override overrideWith(RoomMessages Function() create) {
    return ProviderOverride(
      origin: this,
      override: RoomMessagesProvider._internal(
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
  AutoDisposeNotifierProviderElement<RoomMessages, List<ChatMessage>>
  createElement() {
    return _RoomMessagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RoomMessagesProvider && other.roomId == roomId;
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
mixin RoomMessagesRef on AutoDisposeNotifierProviderRef<List<ChatMessage>> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _RoomMessagesProviderElement
    extends AutoDisposeNotifierProviderElement<RoomMessages, List<ChatMessage>>
    with RoomMessagesRef {
  _RoomMessagesProviderElement(super.provider);

  @override
  String get roomId => (origin as RoomMessagesProvider).roomId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
