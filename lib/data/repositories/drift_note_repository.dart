import 'package:drift/drift.dart';

import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../local/app_database.dart';

class DriftNoteRepository implements NoteRepository {
  DriftNoteRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Note>> watchAllNotes() {
    return (_db.select(_db.noteRows)
          ..orderBy([
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .map((rows) => rows.map(_mapRowToNote).toList());
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final row = await (_db.select(_db.noteRows)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _mapRowToNote(row);
  }

  @override
  Future<Note> saveNote(Note note) async {
    await _db.into(_db.noteRows).insertOnConflictUpdate(
          NoteRow(
            id: note.id,
            title: note.title,
            content: note.content,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
          ),
        );
    return note;
  }

  @override
  Future<void> deleteNote(String id) async {
    await (_db.delete(_db.noteRows)..where((t) => t.id.equals(id))).go();
  }

  Note _mapRowToNote(NoteRow row) {
    return Note(
      id: row.id,
      title: row.title,
      content: row.content,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
