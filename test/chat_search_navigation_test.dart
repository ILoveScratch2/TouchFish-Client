import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/providers/chat/message_provider.dart';
import 'package:touchfish_client/screens/chat_detail/widgets/message_list_view.dart';
import 'package:touchfish_client/screens/chat_detail_screen.dart';
import 'package:touchfish_client/services/local_message_store.dart';

class _CachedRoomMessages extends RoomMessages {
  @override
  List<ChatMessage> build(String roomId) => [
    for (var mid = 10; mid < 13; mid++)
      ChatMessage(
        id: '$mid',
        mid: mid,
        text: 'Message $mid',
        timestamp: DateTime(2026),
        isMe: true,
      ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens the chat timeline at the selected search message', (
    tester,
  ) async {
    const room = 'G1';
    final store = LocalMessageStore.instance;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.init();
      final directory = await Directory.systemTemp.createTemp();
      addTearDown(() => directory.delete(recursive: true));
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      store.configureScope('https://example.test', 1);
      addTearDown(store.clearScope);
      await store.getRoomSyncMid(room);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomMessagesProvider(room).overrideWith(_CachedRoomMessages.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatDetailScreen(roomId: room, initialMessageMid: 11),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final timeline = tester.widget<MessageListView>(
      find.byType(MessageListView),
    );
    expect(timeline.highlightedMid, 11);
    await tester.pumpWidget(const SizedBox());
  });
}
