import 'dart:async';
import 'package:flutter/foundation.dart';

/// Debounces typing and serializes writes. A failed write retains the dirty
/// revision so Retry or leaving the page can attempt it again.
class AutosaveController extends ChangeNotifier {
  AutosaveController(
    this._save, {
    this.delay = const Duration(milliseconds: 400),
  });
  final Future<void> Function() _save;
  final Duration delay;
  Timer? _timer;
  Future<bool>? _running;
  int _revision = 0;
  int _savedRevision = 0;
  bool _stopped = false;
  bool _disposed = false;
  Object? error;

  bool get dirty => _revision != _savedRevision;
  bool get saving => _running != null;

  void changed() {
    if (_stopped) return;
    _revision++;
    error = null;
    _timer?.cancel();
    _timer = Timer(delay, flush);
    _notify();
  }

  Future<bool> flush() {
    _timer?.cancel();
    _timer = null;
    if (_stopped) return Future.value(!dirty);
    if (_running != null) return _running!;
    if (!dirty) return Future.value(true);
    // Start on a microtask so _running is set before notifying listeners.
    return _running = Future.microtask(_drain);
  }

  Future<bool> _drain() async {
    _notify();
    try {
      while (dirty && !_stopped && !_disposed) {
        final revision = _revision;
        await _save();
        _savedRevision = revision;
        error = null;
      }
      return !dirty;
    } on Object catch (failure) {
      error = failure;
      return false;
    } finally {
      _running = null;
      _notify();
    }
  }

  /// Stop before deletion, then wait for a started write so it cannot recreate
  /// the deleted item. Normal navigation flushes instead.
  Future<void> stop() async {
    _stopped = true;
    _timer?.cancel();
    await _running;
  }

  void resume() {
    _stopped = false;
    if (dirty) changed();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
