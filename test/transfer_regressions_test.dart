import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:touchfish_client/models/upload_session.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';
import 'package:touchfish_client/services/file_service.dart';

void main() {
  test('group summaries accept old rows and both member list formats', () {
    final legacy = [1, 2, 'Group', '[2,3]', [], '', '', 1];
    final current = [
      3,
      4,
      'New',
      [4, 5],
      [],
      '',
      '',
      0,
      1,
    ];

    expect(decodeGroupSummary(legacy)?['members'], [2, 3]);
    expect(decodeGroupSummary(legacy)?['require_review'], isNull);
    expect(decodeGroupSummary(current)?['members'], [4, 5]);
    expect(decodeGroupSummary(current)?['require_review'], 1);
    expect(decodeGroupSummary([1, 2]), isNull);
  });

  test(
    'upload resumption requires the original file and unfinished chunks',
    () {
      final now = DateTime.now();
      final session = UploadSession(
        sessionId: 'session',
        filePath: '/tmp/photo.png',
        fileName: 'photo.png',
        fileSize: 15,
        chunkSize: 10,
        totalChunks: 2,
        uploadedChunks: {0},
        expectedHash: 'original',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );

      bool resumes(UploadSession session, {String hash = 'original'}) =>
          session.canResume(
            hash: hash,
            name: 'photo.png',
            size: 15,
            bytesPerChunk: 10,
            chunks: 2,
          );
      expect(resumes(session), isTrue);
      expect(resumes(session, hash: 'changed'), isFalse);
      expect(resumes(session.copyWith(uploadedChunks: {0, 1})), isFalse);
      expect(resumes(session.copyWith(uploadedChunks: {-1, 0})), isFalse);
    },
  );

  test('an incomplete download preserves the destination', () async {
    final directory = await Directory.systemTemp.createTemp();
    addTearDown(() => directory.delete(recursive: true));
    final destination = File(p.join(directory.path, 'notes.txt'));
    await destination.writeAsString('existing contents');

    final error = StateError('download stopped');
    await expectLater(
      writeDownloadAtomically(destination.path, (path) async {
        await File(path).writeAsString('incomplete');
        throw error;
      }),
      throwsA(same(error)),
    );
    expect(await destination.readAsString(), 'existing contents');
    expect(await directory.list().length, 1);

    await writeDownloadAtomically(destination.path, (path) async {
      await File(path).writeAsString('new contents');
    });
    expect(await destination.readAsString(), 'new contents');
    expect(await directory.list().length, 1);
  });
}
