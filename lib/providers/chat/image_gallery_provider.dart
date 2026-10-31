import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/message_model.dart';
import '../../widgets/media/image_lightbox.dart';
import 'message_provider.dart';

part 'image_gallery_provider.g.dart';

/// 图片画廊
///
/// 只收录图片消息（image 类型或 image/* 的 file），按时间序排列。
@riverpod
class ImageGallery extends _$ImageGallery {
  static const int _galleryCap = 3000;

  int? _lastSignature;
  ImageGalleryState? _lastState;
  String? _lastRoomId;

  @override
  ImageGalleryState build(String roomId) {
    // 为了避免内存 BOOM
    if (ref.watch(roomMessagesProvider(roomId)).length > _galleryCap) {
      final cached = _lastState;
      if (cached != null && _lastRoomId == roomId && cached.isOverLimit) {
        return cached;
      }
      final next = ImageGalleryState.overLimit(roomId);
      _lastRoomId = roomId;
      _lastSignature = null;
      _lastState = next;
      return next;
    }

    final messages = ref.watch(imageMessagesProvider(roomId));

    final signature = _signatureOf(messages);
    final cached = _lastState;
    if (cached != null &&
        _lastRoomId == roomId &&
        _lastSignature == signature) {
      return cached;
    }

    final entries = <LightboxImageItem>[];
    // 用稳定标识做键
    final indexById = <String, int>{};

    for (final message in messages) {
      if (!_isImageMessage(message)) continue;
      final media = message.media!;
      final index = entries.length;
      final raw = media.bytes;
      entries.add(
        LightboxImageItem(
          messageId: message.id,
          media: media,
          // 直接共享 media.bytes（只有类型不是 Uint8List 时才复制）：
          // 每来一条新消息都会重建画廊，逐张复制会放大成倍内存
          bytes: raw is Uint8List
              ? raw
              : (raw != null ? Uint8List.fromList(raw) : null),
        ),
      );
      indexById[imageGalleryKey(message)] = index;
    }

    final next = ImageGalleryState(
      roomId: roomId,
      items: entries,
      indexById: indexById,
    );
    _lastRoomId = roomId;
    _lastSignature = signature;
    _lastState = next;
    return next;
  }

  /// 图片集合整数指纹
  int _signatureOf(List<ChatMessage> messages) {
    var hash = 0x1fffffff;
    var count = 0;
    for (final message in messages) {
      if (!_isImageMessage(message)) continue;
      count++;
      hash = (hash * 31 + message.id.hashCode) & 0x3fffffff;
      final mid = message.mid;
      if (mid != null) hash = (hash * 31 + mid) & 0x3fffffff;
      final bytes = message.media?.bytes;
      hash = (hash * 31 + (bytes?.length ?? -1)) & 0x3fffffff;
    }
    return Object.hash(count, hash);
  }

  static bool _isImageMessage(ChatMessage message) {
    if (message.media == null) return false;
    return message.type == MessageType.image ||
        (message.type == MessageType.file &&
            (message.media!.mimeType ?? '').startsWith('image/'));
  }
}

/// 消息在画廊中的稳定键
String imageGalleryKey(ChatMessage message) {
  final mid = message.mid;
  return mid != null ? 'm$mid' : 'id:${message.id}';
}

class ImageGalleryState {
  final String roomId;
  final List<LightboxImageItem> items;
  final Map<String, int> indexById;
  final bool isOverLimit;

  ImageGalleryState({
    required this.roomId,
    required this.items,
    required this.indexById,
    this.isOverLimit = false,
  });

  factory ImageGalleryState.overLimit(String roomId) {
    return ImageGalleryState(
      roomId: roomId,
      items: [],
      indexById: {},
      isOverLimit: true,
    );
  }
}
