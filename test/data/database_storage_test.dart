import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:romlerk_mobile/data/local/database_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late DatabaseStorage storage;

  File shared(String suffix) =>
      File(p.join(docs.path, '${DatabaseStorage.fileName}$suffix'));
  File private(String suffix) => File(
    p.join(
      docs.path,
      DatabaseStorage.privateDirectory,
      '${DatabaseStorage.fileName}$suffix',
    ),
  );

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('romlerk_storage');
    storage = DatabaseStorage(documents: () async => docs);
  });

  tearDown(() => docs.delete(recursive: true));

  test('backup is on by default and the database stays shared', () async {
    shared('').writeAsStringSync('db');
    expect(await storage.backupEnabled(), isTrue);

    final file = await storage.resolveDatabaseFile();
    expect(file.path, shared('').path);
    expect(await storage.changePending(), isFalse);
  });

  test('turning backup off moves the database and its sidecars', () async {
    shared('').writeAsStringSync('db');
    shared('-wal').writeAsStringSync('wal');

    await storage.setBackupEnabled(false);
    expect(await storage.changePending(), isTrue);

    final file = await storage.resolveDatabaseFile();
    expect(file.path, private('').path);
    expect(private('').readAsStringSync(), 'db');
    expect(private('-wal').readAsStringSync(), 'wal');
    expect(shared('').existsSync(), isFalse);
    expect(await storage.changePending(), isFalse);
  });

  test('turning backup back on moves it back', () async {
    await storage.setBackupEnabled(false);
    shared('').writeAsStringSync('db');
    await storage.resolveDatabaseFile();

    await storage.setBackupEnabled(true);
    final file = await storage.resolveDatabaseFile();
    expect(file.path, shared('').path);
    expect(shared('').readAsStringSync(), 'db');
    expect(private('').existsSync(), isFalse);
  });

  test('a first launch with backup off starts in the private directory',
      () async {
    await storage.setBackupEnabled(false);
    final file = await storage.resolveDatabaseFile();
    expect(file.path, private('').path);
    expect(file.existsSync(), isFalse);
  });
}
