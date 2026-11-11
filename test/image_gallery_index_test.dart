import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/providers/chat/image_gallery_provider.dart';
import 'package:touchfish_client/providers/chat/message_provider.dart';

ChatMessage _imageMessage({
  required int mid,
  String id = '',
  List<int>? bytes,
}) {
  return ChatMessage(
    id: id.isEmpty ? 'local-$mid' : id,
    mid: mid,
    text: '',
    timestamp: DateTime(2026, 1, 1).add(Duration(seconds: mid)),
    isMe: false,
    type: MessageType.image,
    media: MessageMedia(
      path: '/files/$mid.jpg',
      fileHash: 'hash-$mid',
      mimeType: 'image/jpeg',
      bytes: bytes,
    ),
  );
}

void main() {
  const roomId = 'U1';

  ProviderContainer containerWith(List<ChatMessage> messages) {
    final container = ProviderContainer(
      overrides: [
        imageMessagesProvider(roomId).overrideWith((ref) => messages),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('index follows chronological order for two images', () {
    final first = _imageMessage(mid: 10);
    final second = _imageMessage(mid: 11);
    final container = containerWith([first, second]);

    final state = container.read(imageGalleryProvider(roomId));

    expect(state.items.length, 2);
    expect(state.indexById[imageGalleryKey(first)], 0);
    expect(state.indexById[imageGalleryKey(second)], 1);
  });

  test(
    'index survives a rebuild with new instances sharing the same mid',
    () {
      final container = containerWith([
        _imageMessage(mid: 10),
        _imageMessage(mid: 11),
      ]);
      container.read(imageGalleryProvider(roomId));
      final rebuiltFirst = _imageMessage(mid: 10);
      final rebuiltSecond = _imageMessage(mid: 11);

      final state = container.read(imageGalleryProvider(roomId));

      expect(state.indexById[imageGalleryKey(rebuiltFirst)], 0);
      expect(
        state.indexById[imageGalleryKey(rebuiltSecond)],
        1,
        reason: 'should locate to 1 not 0 (not Chengdu)',
      );
    },
  );

  test('falls back to the local id when mid is missing', () {
    final a = ChatMessage(
      id: 'local-a',
      text: '',
      timestamp: DateTime(2026, 1, 1),
      isMe: true,
      type: MessageType.image,
      media: const MessageMedia(path: '/a.jpg', mimeType: 'image/jpeg'),
    );
    expect(imageGalleryKey(a), 'id:local-a');
  });

  test('non-image messages are excluded from the index', () {
    final text = ChatMessage(
      id: 'local-t',
      mid: 1,
      text: 'hello',
      timestamp: DateTime(2026, 1, 1),
      isMe: false,
    );
    final image = _imageMessage(mid: 2);
    final container = containerWith([text, image]);

    final state = container.read(imageGalleryProvider(roomId));

    expect(state.items.length, 1);
    expect(state.indexById.containsKey(imageGalleryKey(text)), isFalse);
    expect(state.indexById[imageGalleryKey(image)], 0);
  });
}
