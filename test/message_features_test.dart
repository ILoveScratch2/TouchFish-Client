import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/file_attachment.dart';
import 'package:touchfish_client/models/forum_model.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/models/notification_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';
import 'package:touchfish_client/services/chat_data_service.dart';
import 'package:touchfish_client/widgets/message_bubble.dart';
import 'package:touchfish_client/widgets/file_attachment_view.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  test('history parses quote previews and recalled messages as tombstones', () {
    final replied = ChatMessage.fromMessageRecord({
      'mid': 12,
      'sender_uid': 2,
      'content': 'answer',
      'content_type': 'plain',
      'send_time': 10,
      'quote': 8,
      'quote_preview': {
        'mid': 8,
        'sender_uid': 1,
        'sender_name': 'Alice',
        'content': 'question',
      },
    }, 2);
    expect(replied.quoteMid, 8);
    expect(replied.quotePreview?.content, 'question');

    final recalled = ChatMessage.fromMessageRecord({
      'mid': 13,
      'sender_uid': 2,
      'content': 'must not survive',
      'content_type': 'file',
      'file_hash': 'secret',
      'send_time': 11,
      'deleted': true,
      'deleted_by': 2,
    }, 2);
    expect(recalled.isDeleted, isTrue);
    expect(recalled.text, isEmpty);
    expect(recalled.media, isNull);
    expect(recalled.deletedBy, 2);
  });

  test('attachment metadata accepts backend aliases and detects previews', () {
    final attachment = FileAttachment.fromMap({
      'file_hash': 'abc',
      'name': 'notes.txt',
      'file_size': 42,
      'content_type': 'text/plain',
    });
    expect(attachment.hash, 'abc');
    expect(attachment.fileName, 'notes.txt');
    expect(attachment.fileSize, 42);
    expect(attachment.isText, isTrue);
    expect(attachment.isPreviewable, isTrue);
    expect(
      FileAttachment.fromMap({
        'hash': 'fallback-hash',
        'file_name': null,
      }).fileName,
      'fallback-hash',
    );
  });

  test(
    'automatic preview honors file type, known size and configured limit',
    () {
      const smallImage = FileAttachment(
        hash: 'image',
        fileName: 'image.png',
        fileSize: 1024 * 1024,
        mimeType: 'image/png',
      );
      expect(
        shouldAutomaticallyPreviewFile(attachment: smallImage, limitMiB: 10),
        isTrue,
      );
      expect(
        shouldAutomaticallyPreviewFile(attachment: smallImage, limitMiB: 0),
        isFalse,
      );
      expect(
        shouldAutomaticallyPreviewFile(
          attachment: const FileAttachment(
            hash: 'large',
            fileName: 'large.png',
            fileSize: 11 * 1024 * 1024,
            mimeType: 'image/png',
          ),
          limitMiB: 10,
        ),
        isFalse,
      );
    },
  );

  test('forum post_rows maps creator and attachment metadata', () {
    final post = ForumPost.fromJson({
      'fid': 3,
      'pid': 7,
      'creater': 2,
      'title': 'Post',
      'content': 'Body',
      'send_time': 10.0,
      'attachments': [
        {
          'hash': 'pdf-hash',
          'file_name': 'spec.pdf',
          'size': 2048,
          'mime_type': 'application/pdf',
        },
      ],
    });
    expect(post.authorUid, '2');
    expect(post.attachments.single.fileName, 'spec.pdf');
    expect(post.attachments.single.isPdf, isTrue);
  });

  test('nested notifications retain quote and file metadata', () {
    final notification = NotificationInfo.fromServerJson({
      'info': {
        'info': {
          'event': 'message.file',
          'content': 'abc',
          'sender': 'U2',
          'mid': 9,
          'meta': 4,
          'quote_preview': {'mid': 4, 'sender_uid': 1, 'content': 'quoted'},
          'file_hash': 'abc',
          'file': {
            'hash': 'abc',
            'file_name': 'photo.png',
            'size': 100,
            'mime_type': 'image/png',
          },
        },
      },
    });
    final message = ChatMessage.fromNotification(
      notification: notification,
      myUid: 1,
    );
    expect(message.quoteMid, 4);
    expect(message.quotePreview?.content, 'quoted');
    expect(message.media?.fileName, 'photo.png');
    expect(message.media?.fileSize, 100);
  });

  test('history and notifications retain forwarded message previews', () {
    final history = ChatMessage.fromMessageRecord({
      'mid': 15,
      'sender_uid': 2,
      'content': 'forwarded body',
      'content_type': 'plain',
      'send_time': 12,
      'forwarded': 9,
      'forward_preview': {
        'mid': 9,
        'sender_uid': 3,
        'sender_name': 'Carol',
        'content': 'forwarded body',
      },
    }, 1);
    expect(history.forwardedMid, 9);
    expect(history.forwardPreview?.senderName, 'Carol');

    final notification = NotificationInfo.fromServerJson({
      'info': {
        'event': 'message.plain',
        'content': 'forwarded body',
        'sender': 'U2',
        'mid': 15,
        'forwarded': 9,
        'forward_preview': {
          'mid': 9,
          'sender_uid': 3,
          'content': 'forwarded body',
        },
      },
    });
    final realtime = ChatMessage.fromNotification(
      notification: notification,
      myUid: 1,
    );
    expect(realtime.forwardedMid, 9);
    expect(realtime.forwardPreview?.content, 'forwarded body');
  });

  test('recall redacts target and every cached quote preview', () {
    final messages = [
      ChatMessage(
        id: '4',
        mid: 4,
        text: 'secret',
        timestamp: DateTime(2026),
        isMe: false,
        type: MessageType.file,
        media: const MessageMedia(
          path: 'hash',
          fileHash: 'hash',
          fileName: 'secret.pdf',
        ),
      ),
      ChatMessage(
        id: '5',
        mid: 5,
        text: 'reply',
        timestamp: DateTime(2026, 1, 2),
        isMe: true,
        quoteMid: 4,
        quotePreview: const QuotedMessagePreview(
          mid: 4,
          content: 'secret',
          contentType: 'file',
        ),
      ),
    ];
    final updated = ChatDataService.applyRecallToMessages(messages, 4);
    expect(updated.first.isDeleted, isTrue);
    expect(updated.first.text, isEmpty);
    expect(updated.first.media, isNull);
    expect(updated.last.quotePreview?.isDeleted, isTrue);
    expect(updated.last.quotePreview?.content, isEmpty);
    expect(updated.last.quotePreview?.contentType, 'plain');
  });

  test('chat list honors last_deleted without retaining content', () {
    final item = TfChatListItem.fromJson({
      'room_id': 'U2',
      'room_type': 'direct',
      'partner_uid': 2,
      'username': 'Alice',
      'last_mid': 9,
      'last_content': 'stale secret',
      'last_deleted': true,
      'is_friend': true,
    });
    expect(item.lastDeleted, isTrue);
    expect(item.lastMid, 9);
    expect(item.visibleLastContent, isNull);
  });

  testWidgets('message bubble renders quote and recalled target states', (
    tester,
  ) async {
    final message = ChatMessage(
      id: '2',
      mid: 2,
      text: 'response',
      timestamp: DateTime(2026),
      isMe: true,
      quoteMid: 1,
      quotePreview: const QuotedMessagePreview(
        mid: 1,
        senderName: 'Alice',
        isDeleted: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MessageBubble(message: message)),
      ),
    );
    expect(find.textContaining('Alice'), findsOneWidget);
    expect(find.text('Recalled message'), findsOneWidget);
    expect(find.text('response'), findsOneWidget);
  });

  testWidgets('history quote without sender name is not marked unavailable', (
    tester,
  ) async {
    final message = ChatMessage.fromMessageRecord({
      'mid': 3,
      'sender_uid': 2,
      'content': 'response',
      'content_type': 'plain',
      'send_time': 10,
      'quote': 1,
      'quote_preview': {
        'mid': 1,
        'sender_uid': 7,
        'content': 'original body',
        'content_type': 'plain',
      },
    }, 2);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MessageBubble(message: message)),
      ),
    );
    expect(find.textContaining('UID:7'), findsOneWidget);
    expect(find.text('原消息不可用'), findsNothing);
    expect(find.text('original body'), findsOneWidget);
  });

  testWidgets(
    'own messages stay right aligned and UID zero quotes remain valid',
    (tester) async {
      final message = ChatMessage.fromMessageRecord({
        'mid': 4,
        'sender_uid': 0,
        'content': 'root response',
        'content_type': 'plain',
        'send_time': 10,
        'quote': 2,
        'quote_preview': {
          'mid': 2,
          'sender_uid': 0,
          'content': 'root original',
          'content_type': 'plain',
        },
      }, 0);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MessageBubble(message: message)),
        ),
      );
      final alignment = tester.widget<Align>(
        find.byKey(const ValueKey('message-alignment-4')),
      );
      expect(alignment.alignment, Alignment.centerRight);
      expect(find.textContaining('UID:0'), findsOneWidget);
      expect(find.text('原消息不可用'), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
      final timeAlign = tester.widget<Align>(
        find.byKey(const ValueKey('message-time-4')),
      );
      expect(timeAlign.alignment, Alignment.centerRight);
    },
  );

  testWidgets('hover actions are anchored above the hovered bubble', (
    tester,
  ) async {
    ChatMessage? replied;
    final message = ChatMessage(
      id: 'hover',
      mid: 8,
      text: 'file controls stay reachable',
      timestamp: DateTime(2026),
      isMe: false,
      senderUid: 2,
      senderName: 'Alice',
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: MessageBubble(
              message: message,
              onReply: (value) => replied = value,
              onForward: (_) {},
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text(message.text)));
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.byKey(const ValueKey('message-actions-hover')), findsOneWidget);
    final compactButtons = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((box) => box.width == 32 && box.height == 32);
    expect(compactButtons.length, greaterThanOrEqualTo(2));
    final replyButton = find.byTooltip('Reply');
    await gesture.moveTo(tester.getCenter(replyButton));
    await tester.pump(const Duration(milliseconds: 200));
    expect(replyButton, findsOneWidget);
    await tester.tap(replyButton);
    await tester.pump();
    expect(replied?.mid, 8);
    await gesture.removePointer();
  });

  testWidgets('quickly crossing messages leaves only one hover action menu', (
    tester,
  ) async {
    final first = ChatMessage(
      id: 'hover-first',
      mid: 21,
      text: 'first hover target',
      timestamp: DateTime(2026),
      isMe: false,
      senderUid: 2,
    );
    final second = ChatMessage(
      id: 'hover-second',
      mid: 22,
      text: 'second hover target',
      timestamp: DateTime(2026),
      isMe: false,
      senderUid: 3,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Column(
              children: [
                MessageBubble(
                  message: first,
                  onReply: (_) {},
                  onForward: (_) {},
                ),
                MessageBubble(
                  message: second,
                  onReply: (_) {},
                  onForward: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text(first.text)));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveTo(tester.getCenter(find.text(second.text)));
    await tester.pump(const Duration(milliseconds: 130));
    expect(
      find.byKey(const ValueKey('message-actions-hover-first')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('message-actions-hover-second')),
      findsOneWidget,
    );
    expect(find.byTooltip('Reply'), findsOneWidget);
    await gesture.removePointer();
  });

  testWidgets('long press menu exposes working reply, forward and recall', (
    tester,
  ) async {
    ChatMessage? replied;
    ChatMessage? forwarded;
    ChatMessage? recalled;
    final message = ChatMessage(
      id: '9',
      mid: 9,
      text: 'Action target',
      timestamp: DateTime(2026),
      isMe: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(
            message: message,
            canRecall: true,
            onReply: (value) => replied = value,
            onForward: (value) => forwarded = value,
            onRecall: (value) => recalled = value,
          ),
        ),
      ),
    );
    await tester.longPress(find.text('Action target'));
    await tester.pumpAndSettle();
    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Recall'), findsOneWidget);
    expect(find.text('Forward'), findsOneWidget);
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(replied?.mid, 9);

    await tester.longPress(find.text('Action target'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forward'));
    await tester.pumpAndSettle();
    expect(forwarded?.mid, 9);

    await tester.longPress(find.text('Action target'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recall'));
    await tester.pumpAndSettle();
    expect(recalled?.mid, 9);
  });
}
