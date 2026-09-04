import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/message_model.dart';
import '../../widgets/media/image_lightbox.dart';
import 'message_provider.dart';

part 'image_gallery_provider.g.dart';

/// 图片画廊
@riverpod
class ImageGallery extends _$ImageGallery {
  static const int _galleryCap = 3000;

  @override
  ImageGalleryState build(String roomId) {
    // 惰性构建：开灯箱时才扫描消息列表，平时不占内存
    return ImageGalleryState.empty(roomId);
  }

  /// 构建画廊条目（打开灯箱前调用一次）；此后新图片走 [addImage] 增量接入
  ImageGalleryState buildGallery() {
    final messages = ref.read(roomMessagesProvider(roomId));
    
    if (messages.length > _galleryCap) {
      return ImageGalleryState.overLimit(roomId);
    }

    final entries = <LightboxImageItem>[];
    final indexById = <ChatMessage, int>{};

    for (final message in messages) {
      if (message.media != null) {
        final index = entries.length;
        entries.add(LightboxImageItem(
          messageId: message.id,
          media: message.media!,
          bytes: message.media!.bytes != null 
            ? Uint8List.fromList(message.media!.bytes!) 
            : null,
        ));
        indexById[message] = index;
      }
    }

    state = ImageGalleryState(
      roomId: roomId,
      items: entries,
      indexById: indexById,
      isBuilt: true,
    );

    return state;
  }

  /// 增量添加单张图片（须先调用 [buildGallery]，否则丢弃——与灯箱只展示
  /// 打开时条目的语义一致，新消息在下次打开时自然包含）
  void addImage(ChatMessage message) {
    if (!state.isBuilt) return;
    if (message.media == null) return;
    
    final newIndex = state.items.length;
    final newItems = [
      ...state.items,
      LightboxImageItem(
        messageId: message.id,
        media: message.media!,
        bytes: message.media!.bytes != null 
          ? Uint8List.fromList(message.media!.bytes!) 
          : null,
      ),
    ];
    final newIndexById = {...state.indexById, message: newIndex};

    state = state.copyWith(
      items: newItems,
      indexById: newIndexById,
    );
  }

  /// 清空
  void clear() {
    state = ImageGalleryState.empty(roomId);
  }
}

class ImageGalleryState {
  final String roomId;
  final List<LightboxImageItem> items;
  final Map<ChatMessage, int> indexById;
  final bool isBuilt;
  final bool isOverLimit;

  ImageGalleryState({
    required this.roomId,
    required this.items,
    required this.indexById,
    this.isBuilt = false,
    this.isOverLimit = false,
  });

  factory ImageGalleryState.empty(String roomId) {
    return ImageGalleryState(
      roomId: roomId,
      items: [],
      indexById: {},
      isBuilt: false,
    );
  }

  factory ImageGalleryState.overLimit(String roomId) {
    return ImageGalleryState(
      roomId: roomId,
      items: [],
      indexById: {},
      isBuilt: false,
      isOverLimit: true,
    );
  }

  ImageGalleryState copyWith({
    List<LightboxImageItem>? items,
    Map<ChatMessage, int>? indexById,
    bool? isBuilt,
  }) {
    return ImageGalleryState(
      roomId: roomId,
      items: items ?? this.items,
      indexById: indexById ?? this.indexById,
      isBuilt: isBuilt ?? this.isBuilt,
      isOverLimit: isOverLimit,
    );
  }
}
