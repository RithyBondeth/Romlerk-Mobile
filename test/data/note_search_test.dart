import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/data/local/app_database.dart';
import 'package:romlerk_mobile/data/repositories/drift_note_repository.dart';
import 'package:romlerk_mobile/domain/entities/note.dart';

void main() {
  late AppDatabase db;
  late DriftNoteRepository notes;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notes = DriftNoteRepository(db);
  });
  tearDown(() => db.close());
  test(
    'search matches titles/body, Khmer, and literal SQL wildcard characters',
    () async {
      final now = DateTime.now();
      await notes.saveNote(
        Note(
          id: 'one',
          title: 'Meeting',
          content: 'Budget 50%_done ភ្នំពេញ',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await notes.saveNote(
        Note(
          id: 'two',
          title: 'Other',
          content: 'Budget 500done',
          createdAt: now,
          updatedAt: now,
        ),
      );
      for (final query in ['MEETING', 'ភ្នំពេញ', '50%_', 'done ភ្នំពេញ']) {
        expect(
          (await notes.watchAllNotes(text: query).first).map((n) => n.id),
          ['one'],
        );
      }
      expect((await notes.watchAllNotes(text: 'no match').first), isEmpty);
    },
  );
}
