import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/application/editing/autosave_controller.dart';

void main() {
  testWidgets('typing is debounced but flush saves immediately', (
    tester,
  ) async {
    var writes = 0;
    final controller = AutosaveController(() async {
      writes++;
    });
    controller.changed();
    await tester.pump(const Duration(milliseconds: 200));
    controller.changed();
    await tester.pump(const Duration(milliseconds: 200));
    expect(writes, 0);
    await controller.flush();
    expect(writes, 1);
    expect(controller.dirty, isFalse);
    controller.dispose();
  });
  test(
    'edits during an in-flight write are serialized and saved last',
    () async {
      final gate = Completer<void>();
      var input = 'first';
      final saved = <String>[];
      final controller = AutosaveController(() async {
        final snapshot = input;
        if (saved.isEmpty) await gate.future;
        saved.add(snapshot);
      });
      controller.changed();
      final flushing = controller.flush();
      await Future<void>.delayed(Duration.zero);
      input = 'latest';
      controller.changed();
      gate.complete();
      expect(await flushing, isTrue);
      expect(saved, ['first', 'latest']);
      controller.dispose();
    },
  );
  test('failed save stays dirty and can be retried', () async {
    var fail = true;
    final controller = AutosaveController(() async {
      if (fail) throw StateError('Disk full');
    });
    controller.changed();
    expect(await controller.flush(), isFalse);
    expect(controller.dirty, isTrue);
    expect(controller.error, isNotNull);
    fail = false;
    expect(await controller.flush(), isTrue);
    expect(controller.error, isNull);
    controller.dispose();
  });
  test(
    'stop waits for started writes and prevents queued writes before deletion',
    () async {
      final gate = Completer<void>();
      var writes = 0;
      final controller = AutosaveController(() async {
        await gate.future;
        writes++;
      });
      controller.changed();
      final flush = controller.flush();
      await Future<void>.delayed(Duration.zero);
      controller.changed();
      final stopped = controller.stop();
      gate.complete();
      await stopped;
      await flush;
      expect(writes, 1);
      controller.changed();
      expect(await controller.flush(), isFalse);
      controller.dispose();
    },
  );
}
