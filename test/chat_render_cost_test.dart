import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/models/typing_status.dart';
import 'package:touchfish_client/screens/chat_detail/widgets/message_list_view.dart';
import 'package:touchfish_client/widgets/typing_indicator.dart';
import 'package:touchfish_client/widgets/file_attachment_view.dart';
import 'package:touchfish_client/widgets/message_bubble.dart';

class _CountedMessages extends ListBase<ChatMessage> {
  final List<ChatMessage> source;
  int reads = 0;

  _CountedMessages(this.source);

  @override
  int get length => source.length;
  @override
  set length(int value) => throw UnsupportedError('read only');
  @override
  ChatMessage operator [](int index) {
    reads++;
    return source[index];
  }

  @override
  void operator []=(int index, ChatMessage value) =>
      throw UnsupportedError('read only');
}

ChatMessage _message(int mid) => ChatMessage(
  id: 'local-$mid',
  mid: mid,
  text: 'message $mid',
  isMe: false,
  timestamp: DateTime(2026).add(Duration(seconds: mid)),
);

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('file bubbles share an existing typed attachment buffer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final bytes = Uint8List(1024 * 1024);
    await tester.pumpWidget(
      _app(
        MessageBubble(
          message: _message(1).copyWith(
            type: MessageType.file,
            media: MessageMedia(
              path: 'attachment',
              mimeType: 'application/octet-stream',
              fileName: 'document.bin',
              fileSize: bytes.length,
              bytes: bytes,
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<FileAttachmentView>(find.byType(FileAttachmentView)).bytes,
      same(bytes),
    );
  });

  testWidgets(
    'a cached bubble uses the latest retry handler and updates its reason',
    (tester) async {
      var result = 0;
      final failed = _message(
        1,
      ).copyWith(isMe: true, status: MessageStatus.failed);
      Future<void> show(ChatMessage m, int value) => tester.pumpWidget(
        _app(MessageBubble(message: m, onRetry: () => result = value)),
      );
      await show(failed, 1);
      await show(failed, 2);
      await tester.tap(find.byIcon(Icons.error_outline));
      expect(result, 2);
      await show(failed.copyWith(status: MessageStatus.sent), 3);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    },
  );

  testWidgets(
    'stable child lookup has bounded reads after a tail append or history prepend',
    (tester) async {
      const history = 20000;
      final original = List.generate(history, _message);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      Future<SliverChildBuilderDelegate> show(
        List<ChatMessage> messages,
      ) async {
        await tester.pumpWidget(
          _app(
            MessageListView(
              key: UniqueKey(),
              messages: messages,
              scrollController: controller,
              galleryItems: const [],
              imageIndexById: const {},
              essenceMids: const [],
              pinnedMessages: const [],
              essenceEnabled: false,
              currentRoom: null,
              canModerateGroup: false,
              onRefresh: () {},
              onReply: (_) {},
              onForward: (_) {},
              onRecall: (_) {},
              onQuoteTap: (_) {},
              onPinToggle: (_) {},
              onEssenceToggle: (_) {},
              canRecall: (_) => false,
              canDeleteLocally: (_) => false,
              noMessagesText: 'Empty',
              colorScheme: const ColorScheme.light(),
            ),
          ),
        );
        return tester
                .widget<SuperSliverList>(find.byType(SuperSliverList))
                .delegate
            as SliverChildBuilderDelegate;
      }

      final initial = await show(original);
      final context = tester.element(find.byType(SuperSliverList));
      final keys = [
        for (var i = 0; i < 12; i++) initial.builder(context, i)!.key!,
      ];
      for (final prepend in [false, true]) {
        final data = _CountedMessages(
          prepend
              ? [_message(-1), ...original]
              : [...original, _message(history)],
        );
        final delegate = await show(data);
        data.reads = 0;
        for (var i = 0; i < keys.length; i++) {
          expect(delegate.findIndexByKey(keys[i]), prepend ? i : i + 1);
        }
        expect(data.reads, keys.length * (prepend ? 2 : 1));
      }

      final reordered = [...original];
      final moved = reordered.removeLast();
      reordered.insert(50, moved);
      reordered.removeAt(history - 1);
      final reshuffled = await show(reordered);
      expect(reshuffled.findIndexByKey(keys.first), reordered.length - 51);
      expect(reshuffled.findIndexByKey(keys[1]), isNull);
    },
  );

  testWidgets(
    'typing animation paints without rebuilding widgets on each tick',
    (tester) async {
      await tester.pumpWidget(
        _app(
          TypingIndicator(
            typingStatuses: [
              TypingStatus(
                uid: 1,
                scope: 'typing',
                updatedAt: DateTime(2026),
                timestamp: DateTime(2026),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('is typing'), findsOneWidget);
      var rebuilds = 0;
      var dotPaints = 0;
      final oldPaint = debugOnProfilePaint;
      final dots = tester.renderObject<RenderCustomPaint>(
        find.descendant(
          of: find.byType(TypingIndicator),
          matching: find.byType(CustomPaint),
        ),
      );
      final old = debugOnRebuildDirtyWidget;
      try {
        debugOnProfilePaint = (object) {
          if (identical(object, dots)) dotPaints++;
          oldPaint?.call(object);
        };
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          rebuilds++;
          old?.call(element, builtOnce);
        };
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      } finally {
        debugOnRebuildDirtyWidget = old;
        debugOnProfilePaint = oldPaint;
      }
      expect(rebuilds, 0);
      expect(dotPaints, 60);
    },
  );
}
