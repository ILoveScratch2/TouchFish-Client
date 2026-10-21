import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/message_model.dart';
import '../../widgets/media/image_lightbox.dart';
import 'message_provider.dart';

part 'image_gallery_provider.g.dart';

/// 图片画廊
///
/// 只收录图片消息（image 类型或 image/* 的 file），按时间序排列。直接 watch imageMessagesProvider，消息列表变化时
/// 自动重建!
@riverpod
class ImageGallery extends _$ImageGallery {
  static const int _galleryCap = 3000;

  @override
  ImageGalleryState build(String roomId) {
    // 为了避免内存 BOOM
    if (ref.watch(roomMessagesProvider(roomId)).length > _galleryCap) {
      return ImageGalleryState.overLimit(roomId);
    }

    final messages = ref.watch(imageMessagesProvider(roomId));

    final entries = <LightboxImageItem>[];
    final indexById = <ChatMessage, int>{};

    for (final message in messages) {
      if (!_isImageMessage(message)) continue;
      final media = message.media!;
      final index = entries.length;
      final raw = media.bytes;
      entries.add(LightboxImageItem(
        messageId: message.id,
        media: media,
        // 直接共享 media.bytes（只有类型不是 Uint8List 时才复制）：
        // 每来一条新消息都会重建画廊，逐张复制会放大成倍内存
        bytes: raw is Uint8List
            ? raw
            : (raw != null ? Uint8List.fromList(raw) : null),
      ));
      indexById[message] = index;
    }

    return ImageGalleryState(
      roomId: roomId,
      items: entries,
      indexById: indexById,
    );
  }

  static bool _isImageMessage(ChatMessage message) {
    if (message.media == null) return false;
    return message.type == MessageType.image ||
        (message.type == MessageType.file &&
            (message.media!.mimeType ?? '').startsWith('image/'));
  }
}

class ImageGalleryState {
  final String roomId;
  final List<LightboxImageItem> items;
  final Map<ChatMessage, int> indexById;

  ImageGalleryState({
    required this.roomId,
    required this.items,
    required this.indexById,
  });

  factory ImageGalleryState.overLimit(String roomId) {
    return ImageGalleryState(
      roomId: roomId,
      items: [],
      indexById: {},
    );
  }
}
