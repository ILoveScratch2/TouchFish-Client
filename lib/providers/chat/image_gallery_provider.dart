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

  ImageGalleryState? _lastState;

  @override
  ImageGalleryState build(String roomId) {
    // 为了避免内存 BOOM
    if (ref.watch(roomMessagesProvider(roomId).select((m) => m.length > _galleryCap))) {
      final cached = _lastState;
      if (cached != null && cached.roomId == roomId && cached.isOverLimit) {
        return cached;
      }
      final next = ImageGalleryState.overLimit(roomId);
      _lastState = next;
      return next;
    }

    final messages = ref.watch(imageMessagesProvider(roomId));

    final cached = _lastState;
    final previous =
        cached != null && cached.roomId == roomId && !cached.isOverLimit
        ? cached
        : null;
    if (previous != null && _matchesGallery(previous, messages)) {
      return previous;
    }

    final entries = <LightboxImageItem>[];
    // 用稳定标识做键
    final indexById = <String, int>{};

    for (final message in messages) {
      if (!_isImageMessage(message)) continue;
      final media = message.media!;
      final index = entries.length;
      final key = imageGalleryKey(message);
      final oldIndex = previous?.indexById[key];
      final oldItem = oldIndex == null ? null : previous!.items[oldIndex];
      if (oldItem != null &&
          oldItem.messageId == message.id &&
          identical(oldItem.media, media)) {
        entries.add(oldItem);
      } else {
        final raw = media.bytes;
        entries.add(
          LightboxImageItem(
            messageId: message.id,
            media: media,
            bytes: raw is Uint8List
                ? raw
                : (raw == null ? null : Uint8List.fromList(raw)),
          ),
        );
      }
      indexById[key] = index;
    }

    final next = ImageGalleryState(
      roomId: roomId,
      items: entries,
      indexById: indexById,
    );
    _lastState = next;
    return next;
  }

  bool _matchesGallery(ImageGalleryState cached, List<ChatMessage> messages) {
    var index = 0;
    for (final message in messages) {
      if (!_isImageMessage(message)) continue;
      if (index >= cached.items.length ||
          cached.indexById[imageGalleryKey(message)] != index) {
        return false;
      }
      final item = cached.items[index++];
      if (item.messageId != message.id ||
          !identical(item.media, message.media)) {
        return false;
      }
    }
    return index == cached.items.length;
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
