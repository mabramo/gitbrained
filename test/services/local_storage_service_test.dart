import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbrained/services/local_storage_service.dart';

void main() {
  late Directory tempDir;
  late LocalStorageService service;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('gitbrained_test_');
    service = LocalStorageService(overridePath: tempDir.path);
    await service.init();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('writeNote / readNote', () {
    test('round-trip writes and reads content', () async {
      await service.writeNote('notes/hello.md', '# Hello');
      final note = await service.readNote('notes/hello.md');
      expect(note, isNotNull);
      expect(note!.content, '# Hello');
      expect(note.path, 'notes/hello.md');
    });

    test('readNote returns null for non-existent file', () async {
      final note = await service.readNote('does/not/exist.md');
      expect(note, isNull);
    });

    test('readNote reflects dirty state', () async {
      await service.writeNote('a.md', 'content');
      await service.markDirty('a.md');
      final note = await service.readNote('a.md');
      expect(note!.isDirty, isTrue);
    });
  });

  group('markDirty / clearDirty / getDirtyPaths', () {
    test('markDirty adds path to dirty set', () async {
      await service.markDirty('notes/a.md');
      final dirty = await service.getDirtyPaths();
      expect(dirty, contains('notes/a.md'));
    });

    test('clearDirty removes path from dirty set', () async {
      await service.markDirty('notes/a.md');
      await service.clearDirty('notes/a.md');
      final dirty = await service.getDirtyPaths();
      expect(dirty, isNot(contains('notes/a.md')));
    });

    test('getDirtyPaths returns all dirty paths', () async {
      await service.markDirty('a.md');
      await service.markDirty('b.md');
      final dirty = await service.getDirtyPaths();
      expect(dirty, containsAll(['a.md', 'b.md']));
    });
  });

  group('setSha / getAllShas', () {
    test('setSha stores sha and getAllShas retrieves it', () async {
      await service.setSha('notes/a.md', 'abc123');
      final shas = await service.getAllShas();
      expect(shas['notes/a.md'], 'abc123');
    });

    test('getAllShas returns all set shas', () async {
      await service.setSha('a.md', 'sha1');
      await service.setSha('b.md', 'sha2');
      final shas = await service.getAllShas();
      expect(shas['a.md'], 'sha1');
      expect(shas['b.md'], 'sha2');
    });
  });

  group('createFolder', () {
    test('creates .gitkeep placeholder inside the folder', () async {
      await service.createFolder('projects');
      final note = await service.readNote('projects/.gitkeep');
      expect(note, isNotNull);
      expect(note!.content, isEmpty);
    });

    test('marks .gitkeep as dirty', () async {
      await service.createFolder('projects');
      final dirty = await service.getDirtyPaths();
      expect(dirty, contains('projects/.gitkeep'));
    });

    test('creates nested folders', () async {
      await service.createFolder('a/b/c');
      final note = await service.readNote('a/b/c/.gitkeep');
      expect(note, isNotNull);
    });
  });

  group('listLocal', () {
    test('returns dirs before files', () async {
      await service.writeNote('subdir/note.md', 'x');
      await service.writeNote('top.md', 'y');
      final entries = await service.listLocal('');
      final names = entries.map((e) => e.path.split('/').last).toList();
      final subdirIndex = names.indexOf('subdir');
      final topIndex = names.indexOf('top.md');
      expect(subdirIndex, lessThan(topIndex));
    });

    test('excludes .meta directory', () async {
      await service.writeNote('note.md', 'content');
      final entries = await service.listLocal('');
      final paths = entries.map((e) => e.path).toList();
      expect(paths.any((p) => p.contains('.meta')), isFalse);
    });

    test('returns empty list for non-existent directory', () async {
      final entries = await service.listLocal('nonexistent');
      expect(entries, isEmpty);
    });
  });
}
