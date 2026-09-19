import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the task database lives, and so whether the OS backs it up (FR-26).
///
/// The database sits either in the documents directory, which iOS and Android
/// include in their encrypted cloud backup, or in a `private/` subdirectory
/// that both are told to skip: Android through the rules in
/// `res/xml/backup_rules.xml` and `data_extraction_rules.xml`, iOS through the
/// directory's excluded-from-backup flag.
///
/// An open SQLite file cannot safely be moved, so the choice is recorded in a
/// marker file and applied by [resolveDatabaseFile] the next time the database
/// opens. The marker, not the settings table, holds it because the location
/// has to be known before the database can be read.
class DatabaseStorage {
  const DatabaseStorage({
    MethodChannel? channel,
    Future<Directory> Function()? documents,
  }) : _channel = channel ?? const MethodChannel('dev.romlerk/storage'),
       _documentsOverride = documents;

  static const String fileName = 'romlerk.sqlite';
  static const String privateDirectory = 'private';
  static const String _optOutMarker = '.backup_opt_out';

  /// The main file and the ones SQLite writes beside it, which can hold
  /// committed data and must move with it.
  static const List<String> _sidecars = <String>['', '-wal', '-shm', '-journal'];

  final MethodChannel _channel;
  final Future<Directory> Function()? _documentsOverride;

  Future<Directory> _documents() =>
      (_documentsOverride ?? getApplicationDocumentsDirectory)();

  /// What the user chose. Defaults to included.
  Future<bool> backupEnabled() async {
    final docs = await _documents();
    return !File(p.join(docs.path, _optOutMarker)).existsSync();
  }

  Future<void> setBackupEnabled(bool enabled) async {
    final marker = File(p.join((await _documents()).path, _optOutMarker));
    if (enabled) {
      if (marker.existsSync()) await marker.delete();
    } else {
      await marker.create(recursive: true);
    }
  }

  /// Whether the database is somewhere other than the user's choice, which
  /// is true between changing the setting and the next launch.
  Future<bool> changePending() async {
    final docs = await _documents();
    final wantPrivate = !await backupEnabled();
    final inPrivate = File(
      p.join(docs.path, privateDirectory, fileName),
    ).existsSync();
    final inShared = File(p.join(docs.path, fileName)).existsSync();
    if (!inPrivate && !inShared) return false;
    return wantPrivate ? !inPrivate : !inShared;
  }

  /// Moves the database to match the user's choice, then returns the file to
  /// open. Called before the database is opened, never while it is.
  Future<File> resolveDatabaseFile() async {
    final docs = await _documents();
    final wantPrivate = !await backupEnabled();

    final shared = docs.path;
    final private = p.join(docs.path, privateDirectory);
    final target = wantPrivate ? private : shared;
    final other = wantPrivate ? shared : private;

    await Directory(private).create(recursive: true);
    // Kept current on every launch, so a restore or OS update cannot leave
    // the private directory quietly backed up.
    await _excludeFromBackup(private);

    final targetFile = File(p.join(target, fileName));
    final otherFile = File(p.join(other, fileName));
    if (!targetFile.existsSync() && otherFile.existsSync()) {
      for (final suffix in _sidecars) {
        final from = File(p.join(other, '$fileName$suffix'));
        if (from.existsSync()) {
          // Same volume, so this is an atomic rename rather than a copy.
          await from.rename(p.join(target, '$fileName$suffix'));
        }
      }
    }
    return targetFile;
  }

  Future<void> _excludeFromBackup(String path) async {
    try {
      await _channel.invokeMethod<void>(
        'excludeFromBackup',
        <String, Object?>{'path': path},
      );
    } on MissingPluginException {
      // Android excludes the directory through its backup rules instead.
    } on PlatformException {
      // Best effort; the database still opens.
    }
  }
}
