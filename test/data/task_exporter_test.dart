import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/data/export/task_exporter.dart';
import 'package:romlerk_mobile/domain/entities/tag.dart';
import 'package:romlerk_mobile/domain/entities/task.dart';
import 'package:romlerk_mobile/domain/enums.dart';

void main() {
  const exporter = TaskExporter();
  final exportedAt = DateTime(2026, 8, 10, 14, 30);

  Task task({
    String id = 'a',
    String title = 'Call David',
    String? notes,
    List<Tag> tags = const <Tag>[],
  }) {
    return Task(
      id: id,
      title: title,
      notes: notes,
      status: TaskStatus.active,
      priority: TaskPriority.high,
      dueAt: DateTime(2026, 8, 11, 9),
      createdAt: exportedAt,
      updatedAt: exportedAt,
      tags: tags,
    );
  }

  group('JSON', () {
    test('is valid, versioned, and carries every task', () {
      final body = exporter.buildJson(
        <Task>[task(), task(id: 'b', title: 'Buy milk')],
        exportedAt: exportedAt,
      );
      final decoded = jsonDecode(body) as Map<String, dynamic>;

      expect(decoded['schemaVersion'], TaskExporter.exportSchemaVersion);
      expect(decoded['taskCount'], 2);
      expect((decoded['tasks'] as List<dynamic>), hasLength(2));
      expect(
        ((decoded['tasks'] as List<dynamic>).first as Map<String, dynamic>)['title'],
        'Call David',
      );
    });
  });

  group('CSV', () {
    test('starts with a header row', () {
      final lines = exporter.buildCsv(<Task>[task()]).trim().split('\n');
      expect(lines.first.startsWith('id,title,notes'), isTrue);
      expect(lines, hasLength(2));
    });

    test('quotes cells containing commas, quotes, or newlines', () {
      final body = exporter.buildCsv(<Task>[
        task(title: 'Buy milk, eggs', notes: 'She said "soon"'),
      ]);
      expect(body, contains('"Buy milk, eggs"'));
      expect(body, contains('"She said ""soon"""'));
    });

    test('joins tags with a pipe so commas stay unambiguous', () {
      final body = exporter.buildCsv(<Task>[
        task(
          tags: <Tag>[
            Tag(id: '1', name: 'work', colorValue: 0, createdAt: exportedAt),
            Tag(id: '2', name: 'calls', colorValue: 0, createdAt: exportedAt),
          ],
        ),
      ]);
      expect(body, contains('work|calls'));
    });
  });

  test('file names are timestamped and filesystem-safe', () {
    final name = exporter.buildFileName(ExportFormat.json, exportedAt);
    expect(name, 'romlerk-tasks-2026-08-10T14-30-00.json');
    expect(name.contains(':'), isFalse);
  });
}
