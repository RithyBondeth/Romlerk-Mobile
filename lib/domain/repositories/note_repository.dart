import '../entities/note.dart';

abstract interface class NoteRepository {
  Stream<List<Note>> watchAllNotes();
  Future<Note?> getNoteById(String id);
  Future<Note> saveNote(Note note);
  Future<void> deleteNote(String id);
}
