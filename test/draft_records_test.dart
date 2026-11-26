import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/services/draft_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads scoped post drafts with their real IDs and timestamps', () async {
    String encode(String value) => base64Url.encode(utf8.encode(value));

    const scope = 'server_account';
    final firstPost = '${scope}_forum_post_${encode('12')}';
    final secondPost = '${scope}_forum_post_${encode('21')}';
    final comment = '${scope}_forum_comment_${encode('12/9')}';
    final chat = '${scope}_chat_${encode('࿿')}';
    SharedPreferences.setMockInitialValues({
      'touchfish_draft_$firstPost': '{"title":"Older post"}',
      'touchfish_draftmeta_$firstPost': 1000,
      'touchfish_draft_$secondPost': '{"title":"Newer post"}',
      'touchfish_draftmeta_$secondPost': 2000,
      'touchfish_draft_$comment': '{"content":"Pending reply"}',
      'touchfish_draft_$chat': '{"content":"Pending message"}',
      'touchfish_draft_another_account_forum_post_${encode('43')}':
          '{"title":"Different account"}',
    });
    final prefs = await SharedPreferences.getInstance();

    final posts = DraftService.readDraftRecords(
      prefs,
      scope: scope,
      type: 'forum_post',
    );
    expect(posts.map((draft) => draft.id), ['21', '12']);
    expect(posts.first.title, 'Newer post');
    expect(posts.first.updatedAt?.millisecondsSinceEpoch, 2000);

    final all = DraftService.readDraftRecords(prefs, scope: scope);
    expect(
      all.map((draft) => (draft.type, draft.id)),
      containsAll([('forum_comment', '12/9'), ('chat', '࿿')]),
    );
  });
}
