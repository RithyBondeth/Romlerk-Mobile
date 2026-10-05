import 'dart:convert';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../task_service.dart';

class UndoAction {
  UndoAction(this._restore, {DateTime? expiresAt})
    : expiresAt = expiresAt ?? DateTime.now().add(const Duration(seconds: 30));
  final Future<void> Function() _restore;
  final DateTime expiresAt;
  bool _used = false;
  Future<void> undo() async {
    if (_used || DateTime.now().isAfter(expiresAt)) {
      throw StateError('Undo expired');
    }
    _used = true;
    try {
      await _restore();
    } on Object {
      _used = false;
      rethrow;
    }
  }
}

/// Restores an exact task snapshot, including rolled recurrence progress.
/// Refuses to overwrite a task edited since the action or revive erased data.
class TaskUndoService {
  TaskUndoService(this.repository, this.service);
  final TaskRepository repository;
  final TaskService service;
  String _fingerprint(Task t) => jsonEncode({
    'task': t.toJson(),
    'occurrenceIndex': t.occurrenceIndex,
    'updatedAt': t.updatedAt.toIso8601String(),
    'tagIds': t.tags.map((t) => t.id).toList()..sort(),
  });
  Future<UndoAction> toggle(String id) async {
    final before = await repository.findTask(id);
    if (before == null) throw StateError('Task missing');
    final epoch = service.dataEpoch;
    final after = before.isCompleted
        ? await service.reopenTask(id)
        : await service.completeTask(id);
    final expected = _fingerprint(after.task);
    return UndoAction(() async {
      if (epoch != service.dataEpoch) throw StateError('Data replaced');
      final current = await repository.findTask(id);
      if (current == null || _fingerprint(current) != expected) {
        throw StateError('Task changed');
      }
      await service.saveTask(before, requestPermission: false);
    });
  }

  Future<UndoAction> delete(String id) async {
    final before = await repository.findTask(id);
    if (before == null) throw StateError('Task missing');
    final epoch = service.dataEpoch;
    await service.deleteTask(id);
    return UndoAction(() async {
      if (epoch != service.dataEpoch || await repository.findTask(id) != null) {
        throw StateError('Data changed');
      }
      await service.restoreDeletedTask(before);
    });
  }
}
