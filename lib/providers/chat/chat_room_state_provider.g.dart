// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_room_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatRoomStateHash() => r'4227b5f8b7d6d7758f5b8d52fce12def6e3fa5c6';

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

abstract class _$ChatRoomState
    extends BuildlessAutoDisposeNotifier<ChatRoomUiState> {
  late final String roomId;

  ChatRoomUiState build(String roomId);
}

/// 聊天室 UI 状态（滚动位置、回复/转发、选择模式等瞬态）
///
/// Copied from [ChatRoomState].
@ProviderFor(ChatRoomState)
const chatRoomStateProvider = ChatRoomStateFamily();

/// 聊天室 UI 状态（滚动位置、回复/转发、选择模式等瞬态）
///
/// Copied from [ChatRoomState].
class ChatRoomStateFamily extends Family<ChatRoomUiState> {
  /// 聊天室 UI 状态（滚动位置、回复/转发、选择模式等瞬态）
  ///
  /// Copied from [ChatRoomState].
  const ChatRoomStateFamily();

  /// 聊天室 UI 状态（滚动位置、回复/转发、选择模式等瞬态）
  ///
  /// Copied from [ChatRoomState].
  ChatRoomStateProvider call(String roomId) {
    return ChatRoomStateProvider(roomId);
  }

  @override
  ChatRoomStateProvider getProviderOverride(
    covariant ChatRoomStateProvider provider,
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
  String? get name => r'chatRoomStateProvider';
}

/// 聊天室 UI 状态（滚动位置、回复/转发、选择模式等瞬态）
///
/// Copied from [ChatRoomState].
class ChatRoomStateProvider
    extends AutoDisposeNotifierProviderImpl<ChatRoomState, ChatRoomUiState> {
  /// 聊天室 UI 状态（滚动位置、回复/转发、选择模式等瞬态）
  ///
  /// Copied from [ChatRoomState].
  ChatRoomStateProvider(String roomId)
    : this._internal(
        () => ChatRoomState()..roomId = roomId,
        from: chatRoomStateProvider,
        name: r'chatRoomStateProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$chatRoomStateHash,
        dependencies: ChatRoomStateFamily._dependencies,
        allTransitiveDependencies:
            ChatRoomStateFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  ChatRoomStateProvider._internal(
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
  ChatRoomUiState runNotifierBuild(covariant ChatRoomState notifier) {
    return notifier.build(roomId);
  }

  @override
  Override overrideWith(ChatRoomState Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatRoomStateProvider._internal(
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
  AutoDisposeNotifierProviderElement<ChatRoomState, ChatRoomUiState>
  createElement() {
    return _ChatRoomStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatRoomStateProvider && other.roomId == roomId;
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
mixin ChatRoomStateRef on AutoDisposeNotifierProviderRef<ChatRoomUiState> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _ChatRoomStateProviderElement
    extends AutoDisposeNotifierProviderElement<ChatRoomState, ChatRoomUiState>
    with ChatRoomStateRef {
  _ChatRoomStateProviderElement(super.provider);

  @override
  String get roomId => (origin as ChatRoomStateProvider).roomId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
