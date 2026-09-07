import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/file_task.dart';
import 'package:touchfish_client/models/upload_session.dart';

void main() {
  group('FileTask', () {
    test('formatFileSize formats bytes correctly', () {
      expect(FileTask.formatFileSize(0), '0 B');
      expect(FileTask.formatFileSize(500), '500 B');
      expect(FileTask.formatFileSize(1024), '1.0 KB');
      expect(FileTask.formatFileSize(1536), '1.5 KB');
      expect(FileTask.formatFileSize(1024 * 1024), '1.0 MB');
      expect(FileTask.formatFileSize(5 * 1024 * 1024), '5.0 MB');
      expect(FileTask.formatFileSize(1024 * 1024 * 1024), '1.0 GB');
    });

    test('sizeFormatted returns formatted file size', () {
      final task = FileTask(
        id: 'test',
        type: FileTaskType.upload,
        status: FileTaskStatus.transferring,
        fileName: 'test.jpg',
        fileSize: 5 * 1024 * 1024,
        bytesTransferred: 2 * 1024 * 1024,
        createdAt: DateTime.now(),
      );

      expect(task.sizeFormatted, '5.0 MB');
    });

    test('progress calculates correctly', () {
      final task = FileTask(
        id: 'test',
        type: FileTaskType.upload,
        status: FileTaskStatus.transferring,
        fileName: 'test.jpg',
        fileSize: 10 * 1024 * 1024,
        bytesTransferred: 5 * 1024 * 1024,
        createdAt: DateTime.now(),
      );

      expect(task.progress, 0.5);
    });

    test('speedFormatted returns formatted speed', () {
      final now = DateTime.now();
      final task = FileTask(
        id: 'test',
        type: FileTaskType.upload,
        status: FileTaskStatus.transferring,
        fileName: 'test.jpg',
        fileSize: 10 * 1024 * 1024,
        bytesTransferred: 5 * 1024 * 1024,
        createdAt: now.subtract(const Duration(seconds: 5)),
      );

      // 5MB in 5 seconds = approximately 1MB/s (could be slightly less due to timing)
      final speed = task.speedFormatted;
      expect(speed.contains('KB/s') || speed.contains('MB/s'), true);
      expect(task.speedBytesPerSecond, greaterThan(900 * 1024)); // at least 900 KB/s
    });

    test('speedFormatted handles zero elapsed time', () {
      final task = FileTask(
        id: 'test',
        type: FileTaskType.upload,
        status: FileTaskStatus.transferring,
        fileName: 'test.jpg',
        fileSize: 1024,
        bytesTransferred: 0,
        createdAt: DateTime.now(),
      );

      expect(task.speedFormatted, '0 B/s');
    });

    test('progress returns null for unknown file size', () {
      final task = FileTask(
        id: 'test',
        type: FileTaskType.download,
        status: FileTaskStatus.transferring,
        fileName: 'test.jpg',
        fileSize: -1,
        bytesTransferred: 1024,
        createdAt: DateTime.now(),
      );

      expect(task.progress, null);
    });

    test('copyWith creates modified copy', () {
      final task = FileTask(
        id: 'test',
        type: FileTaskType.upload,
        status: FileTaskStatus.transferring,
        fileName: 'test.jpg',
        fileSize: 1024,
        bytesTransferred: 512,
        createdAt: DateTime.now(),
      );

      final updated = task.copyWith(
        bytesTransferred: 1024,
        status: FileTaskStatus.completed,
      );

      expect(updated.bytesTransferred, 1024);
      expect(updated.status, FileTaskStatus.completed);
      expect(updated.fileName, 'test.jpg'); // unchanged
      expect(updated.fileSize, 1024); // unchanged
    });

    test('finishedAt is carried through copyWith', () {
      final finished = DateTime(2026, 9, 1, 12, 0);
      final task = FileTask(
        id: 'test',
        type: FileTaskType.upload,
        status: FileTaskStatus.completed,
        fileName: 'test.jpg',
        fileSize: 1024,
        bytesTransferred: 1024,
        createdAt: DateTime(2026, 9, 1, 11, 0),
        finishedAt: finished,
      );

      final updated = task.copyWith(savePath: '/tmp/x');
      expect(updated.finishedAt, finished);
    });

    test('equality distinguishes finishedAt', () {
      FileTask make({DateTime? finishedAt}) => FileTask(
        id: 'test',
        type: FileTaskType.download,
        status: FileTaskStatus.completed,
        fileName: 'test.jpg',
        fileSize: 1024,
        bytesTransferred: 1024,
        createdAt: DateTime(2026, 9, 1, 11, 0),
        finishedAt: finishedAt,
      );

      expect(
        make(finishedAt: null),
        make(finishedAt: null),
      );
      expect(
        make(finishedAt: DateTime(2026, 9, 1, 12, 0)),
        isNot(make(finishedAt: null)),
      );
    });

    test('upload-specific fields are present', () {
      final task = FileTask(
        id: 'test',
        type: FileTaskType.upload,
        status: FileTaskStatus.transferring,
        fileName: 'test.jpg',
        fileSize: 1024,
        bytesTransferred: 512,
        createdAt: DateTime.now(),
        roomId: 'room123',
        clientMid: 'msg456',
      );

      expect(task.roomId, 'room123');
      expect(task.clientMid, 'msg456');
    });

    test('download-specific fields are present', () {
      final task = FileTask(
        id: 'test',
        type: FileTaskType.download,
        status: FileTaskStatus.transferring,
        fileName: 'test.jpg',
        fileSize: 1024,
        bytesTransferred: 512,
        createdAt: DateTime.now(),
        savePath: '/path/to/save',
      );

      expect(task.savePath, '/path/to/save');
    });

    test('progressLabel returns percentage', () {
      final task = FileTask(
        id: 'test',
        type: FileTaskType.upload,
        status: FileTaskStatus.transferring,
        fileName: 'test.jpg',
        fileSize: 1024,
        bytesTransferred: 512,
        createdAt: DateTime.now(),
      );

      expect(task.progressLabel, '50%');
    });

    test('progressLabel returns ellipsis for unknown size', () {
      final task = FileTask(
        id: 'test',
        type: FileTaskType.download,
        status: FileTaskStatus.transferring,
        fileName: 'test.jpg',
        fileSize: -1,
        bytesTransferred: 512,
        createdAt: DateTime.now(),
      );

      expect(task.progressLabel, '…');
    });
  });

  group('UploadSession', () {
    test('isExpired returns true when expired', () {
      final session = UploadSession(
        sessionId: 'test',
        filePath: '/path/to/file',
        fileName: 'test.jpg',
        fileSize: 1024,
        chunkSize: 512,
        totalChunks: 2,
        uploadedChunks: {0},
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(session.isExpired, true);
    });

    test('isExpired returns false when not expired', () {
      final session = UploadSession(
        sessionId: 'test',
        filePath: '/path/to/file',
        fileName: 'test.jpg',
        fileSize: 1024,
        chunkSize: 512,
        totalChunks: 2,
        uploadedChunks: {0},
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(session.isExpired, false);
    });

    test('remainingChunks calculates correctly', () {
      final session = UploadSession(
        sessionId: 'test',
        filePath: '/path/to/file',
        fileName: 'test.jpg',
        fileSize: 1024,
        chunkSize: 256,
        totalChunks: 4,
        uploadedChunks: {0, 1},
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(session.remainingChunks, 2);
    });

    test('progress calculates correctly', () {
      final session = UploadSession(
        sessionId: 'test',
        filePath: '/path/to/file',
        fileName: 'test.jpg',
        fileSize: 1024,
        chunkSize: 256,
        totalChunks: 4,
        uploadedChunks: {0, 1, 2},
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(session.progress, 0.75);
    });

    test('isComplete returns true when all chunks uploaded', () {
      final session = UploadSession(
        sessionId: 'test',
        filePath: '/path/to/file',
        fileName: 'test.jpg',
        fileSize: 1024,
        chunkSize: 512,
        totalChunks: 2,
        uploadedChunks: {0, 1},
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(session.isComplete, true);
    });

    test('toJson and fromJson round-trip', () {
      final session = UploadSession(
        sessionId: 'test123',
        filePath: '/path/to/file.jpg',
        fileName: 'file.jpg',
        fileSize: 10 * 1024 * 1024,
        chunkSize: 5 * 1024 * 1024,
        totalChunks: 2,
        uploadedChunks: {0},
        expectedHash: 'abc123',
        createdAt: DateTime(2026, 1, 1, 12, 0),
        expiresAt: DateTime(2026, 1, 1, 13, 0),
      );

      final json = session.toJson();
      final restored = UploadSession.fromJson(json);

      expect(restored.sessionId, session.sessionId);
      expect(restored.filePath, session.filePath);
      expect(restored.fileName, session.fileName);
      expect(restored.fileSize, session.fileSize);
      expect(restored.chunkSize, session.chunkSize);
      expect(restored.totalChunks, session.totalChunks);
      expect(restored.uploadedChunks, session.uploadedChunks);
      expect(restored.expectedHash, session.expectedHash);
      expect(restored.createdAt, session.createdAt);
      expect(restored.expiresAt, session.expiresAt);
    });

    test('encode and decode round-trip', () {
      final session = UploadSession(
        sessionId: 'test123',
        filePath: '/path/to/file.jpg',
        fileName: 'file.jpg',
        fileSize: 1024,
        chunkSize: 512,
        totalChunks: 2,
        uploadedChunks: {0},
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final encoded = session.encode();
      final decoded = UploadSession.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.sessionId, session.sessionId);
      expect(decoded.filePath, session.filePath);
      expect(decoded.uploadedChunks, session.uploadedChunks);
    });

    test('decode returns null for expired session', () {
      final session = UploadSession(
        sessionId: 'test',
        filePath: '/path/to/file',
        fileName: 'test.jpg',
        fileSize: 1024,
        chunkSize: 512,
        totalChunks: 2,
        uploadedChunks: {0},
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final encoded = session.encode();
      final decoded = UploadSession.decode(encoded);

      expect(decoded, isNull);
    });

    test('decode returns null for invalid json', () {
      final decoded = UploadSession.decode('invalid json');
      expect(decoded, isNull);
    });
  });
}
