import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/file_task.dart';
import 'package:touchfish_client/providers/task/task_manager_provider.dart';

FileTask _task({
  String id = 't',
  FileTaskType type = FileTaskType.upload,
  FileTaskStatus status = FileTaskStatus.transferring,
  DateTime? createdAt,
  DateTime? finishedAt,
}) {
  return FileTask(
    id: id,
    type: type,
    status: status,
    fileName: 'file_$id.jpg',
    fileSize: 1024,
    bytesTransferred: status == FileTaskStatus.completed ? 1024 : 512,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(seconds: 2)),
    finishedAt: finishedAt,
  );
}

void main() {
  late ProviderContainer container;
  late TaskManager manager;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    manager = container.read(taskManagerProvider.notifier);
  });

  List<FileTask> tasks() => container.read(taskManagerProvider);

  test('addTask appends the task and returns its id', () {
    final id = manager.addTask(_task(id: 'a'));
    expect(id, 'a');
    expect(tasks().map((t) => t.id), ['a']);
  });

  test('updateTask writes finishedAt on completion', () {
    manager.addTask(_task(id: 'a'));
    manager.updateTask('a', status: FileTaskStatus.completed);

    final t = tasks().single;
    expect(t.status, FileTaskStatus.completed);
    expect(t.finishedAt, isNotNull);
    expect(
      DateTime.now().difference(t.finishedAt!).inSeconds,
      lessThanOrEqualTo(1),
    );
  });

  test('updateTask writes finishedAt on failure', () {
    manager.addTask(_task(id: 'a'));
    manager.updateTask('a', status: FileTaskStatus.failed, errorMessage: 'oops');

    final t = tasks().single;
    expect(t.status, FileTaskStatus.failed);
    expect(t.finishedAt, isNotNull);
    expect(t.errorMessage, 'oops');
  });

  test('updateTask keeps finishedAt null while transferring', () {
    manager.addTask(_task(id: 'a'));
    manager.updateTask('a', bytesTransferred: 768);

    final t = tasks().single;
    expect(t.bytesTransferred, 768);
    expect(t.finishedAt, isNull);
  });

  test('updateTask only touches non-null fields', () {
    manager.addTask(_task(id: 'a'));
    manager.updateTask('a', savePath: '/tmp/out');

    final t = tasks().single;
    expect(t.savePath, '/tmp/out');
    expect(t.status, FileTaskStatus.transferring);
    expect(t.bytesTransferred, 512);
    expect(t.errorMessage, isNull);
  });

  test('pruneCompleted keeps a long transfer that just finished', () {
    // Transfer began 60s ago (older than the 8s prune window), so the old
    // createdAt-based pruning would have removed it the tick after completion.
    final old = DateTime.now().subtract(const Duration(seconds: 60));
    manager.addTask(_task(id: 'a', createdAt: old));
    manager.updateTask('a', status: FileTaskStatus.completed);

    manager.pruneCompleted();

    expect(tasks().map((t) => t.id), ['a']);
  });

  test('pruneCompleted removes finished tasks older than maxAge', () {
    final old = DateTime.now().subtract(const Duration(minutes: 1));
    manager.addTask(_task(id: 'done', status: FileTaskStatus.completed, finishedAt: old));
    manager.addTask(_task(id: 'failed', status: FileTaskStatus.failed, finishedAt: old));

    manager.pruneCompleted();

    expect(tasks(), isEmpty);
  });

  test('pruneCompleted keeps active tasks regardless of age', () {
    final old = DateTime.now().subtract(const Duration(minutes: 10));
    manager.addTask(_task(id: 'a', createdAt: old));

    manager.pruneCompleted();

    expect(tasks().map((t) => t.id), ['a']);
  });

  test('pruneCompleted falls back to createdAt when finishedAt is null', () {
    final old = DateTime.now().subtract(const Duration(minutes: 1));
    manager.addTask(_task(id: 'done', status: FileTaskStatus.completed, finishedAt: null, createdAt: old));

    manager.pruneCompleted();

    expect(tasks(), isEmpty);
  });

  test('pruneCompleted honors a custom maxAge', () {
    manager.addTask(_task(
      id: 'done',
      status: FileTaskStatus.completed,
      finishedAt: DateTime.now().subtract(const Duration(seconds: 5)),
    ));

    manager.pruneCompleted(maxAge: const Duration(seconds: 3));
    expect(tasks(), isEmpty);

    manager.addTask(_task(
      id: 'fresh',
      status: FileTaskStatus.completed,
      finishedAt: DateTime.now(),
    ));
    manager.pruneCompleted(maxAge: const Duration(seconds: 3));
    expect(tasks().map((t) => t.id), ['fresh']);
  });

  test('clearCompleted removes finished tasks but keeps active ones', () {
    manager.addTask(_task(id: 'active'));
    manager.addTask(_task(id: 'done', status: FileTaskStatus.completed));
    manager.addTask(_task(id: 'failed', status: FileTaskStatus.failed));

    manager.clearCompleted();

    expect(tasks().map((t) => t.id), ['active']);
  });

  test('clearAll empties the list', () {
    manager.addTask(_task(id: 'a'));
    manager.addTask(_task(id: 'b'));

    manager.clearAll();

    expect(tasks(), isEmpty);
  });

  test('removeTask removes by id', () {
    manager.addTask(_task(id: 'a'));
    manager.addTask(_task(id: 'b'));

    manager.removeTask('a');

    expect(tasks().map((t) => t.id), ['b']);
  });

  test('byClientMid finds the matching upload task', () {
    manager.addTask(_task(id: 'a'));
    manager.addTask(_task(id: 'b').copyWith(roomId: 'room', clientMid: 'm1'));

    expect(manager.byClientMid('m1')?.id, 'b');
    expect(manager.byClientMid('nope'), isNull);
    expect(manager.byClientMid(null), isNull);
  });
}
