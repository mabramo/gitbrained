import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gitbrained/models/note.dart';
import 'package:gitbrained/models/repo_item.dart';
import 'package:gitbrained/services/sync_service.dart';
import 'package:gitbrained/utils/exceptions.dart';
import '../helpers/mock_services.dart';

void main() {
  setUpAll(registerFallbacks);

  late MockConfigService config;
  late MockGitService git;
  late MockLocalStorageService local;
  late SyncService sync;

  setUp(() {
    config = MockConfigService();
    git = MockGitService();
    local = MockLocalStorageService();

    when(() => config.syncIntervalMinutes).thenReturn(10);

    sync = SyncService(config, git, local);
  });

  tearDown(() {
    sync.dispose();
  });

  Note makeNote(String path, {String? sha, bool dirty = false}) {
    return Note(
      path: path,
      content: 'content of $path',
      remoteSha: sha,
      isDirty: dirty,
      lastModified: DateTime.now(),
    );
  }

  RepoItem makeItem(String name, String path, {bool isDir = false}) {
    return RepoItem(
      name: name,
      path: path,
      sha: 'sha-$name',
      type: isDir ? 'dir' : 'file',
    );
  }

  group('sync()', () {
    test('pushes dirty files and calls createOrUpdateFile', () async {
      when(() => local.getDirtyPaths()).thenAnswer((_) async => {'notes/a.md'});
      when(() => local.readNote('notes/a.md'))
          .thenAnswer((_) async => makeNote('notes/a.md', sha: 'oldsha'));
      when(() => git.createOrUpdateFile(
            path: 'notes/a.md',
            content: any(named: 'content'),
            sha: 'oldsha',
          )).thenAnswer((_) async => 'newsha');
      when(() => local.setSha('notes/a.md', 'newsha')).thenAnswer((_) async {});
      when(() => local.clearDirty('notes/a.md')).thenAnswer((_) async {});
      when(() => git.listDirectory('')).thenAnswer((_) async => []);
      when(() => local.getAllShas()).thenAnswer((_) async => {});

      await sync.sync();

      verify(() => git.createOrUpdateFile(
            path: 'notes/a.md',
            content: any(named: 'content'),
            sha: 'oldsha',
          )).called(1);
    });

    test('clears dirty flag after successful push', () async {
      when(() => local.getDirtyPaths()).thenAnswer((_) async => {'notes/b.md'});
      when(() => local.readNote('notes/b.md'))
          .thenAnswer((_) async => makeNote('notes/b.md', sha: 'sha1'));
      when(() => git.createOrUpdateFile(
            path: 'notes/b.md',
            content: any(named: 'content'),
            sha: 'sha1',
          )).thenAnswer((_) async => 'newsha2');
      when(() => local.setSha('notes/b.md', 'newsha2')).thenAnswer((_) async {});
      when(() => local.clearDirty('notes/b.md')).thenAnswer((_) async {});
      when(() => git.listDirectory('')).thenAnswer((_) async => []);
      when(() => local.getAllShas()).thenAnswer((_) async => {});

      await sync.sync();

      verify(() => local.clearDirty('notes/b.md')).called(1);
    });

    test('adds to conflicts list on ConflictException', () async {
      when(() => local.getDirtyPaths()).thenAnswer((_) async => {'notes/c.md'});
      when(() => local.readNote('notes/c.md'))
          .thenAnswer((_) async => makeNote('notes/c.md', sha: 'sha1'));
      when(() => git.createOrUpdateFile(
            path: 'notes/c.md',
            content: any(named: 'content'),
            sha: 'sha1',
          )).thenThrow(const ConflictException('Conflict'));
      when(() => git.listDirectory('')).thenAnswer((_) async => []);
      when(() => local.getAllShas()).thenAnswer((_) async => {});

      await sync.sync();

      expect(sync.currentState.conflicts, contains('notes/c.md'));
      expect(sync.currentState.status, SyncStatus.conflict);
    });

    test('updates lastSync on success', () async {
      when(() => local.getDirtyPaths()).thenAnswer((_) async => {});
      when(() => git.listDirectory('')).thenAnswer((_) async => []);
      when(() => local.getAllShas()).thenAnswer((_) async => {});

      final before = DateTime.now();
      await sync.sync();
      final after = DateTime.now();

      expect(sync.currentState.lastSync, isNotNull);
      expect(
        sync.currentState.lastSync!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        sync.currentState.lastSync!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('does not run if already syncing', () async {
      // Simulate already-syncing state by starting sync and calling again
      final completer = Completer<void>();
      var callCount = 0;

      when(() => local.getDirtyPaths()).thenAnswer((_) async {
        callCount++;
        await completer.future;
        return {};
      });
      when(() => git.listDirectory('')).thenAnswer((_) async => []);
      when(() => local.getAllShas()).thenAnswer((_) async => {});

      // Start first sync (won't complete until completer fires)
      final first = sync.sync();
      // Second sync call should return immediately because status is syncing
      await sync.sync();

      // Only one invocation of getDirtyPaths (the first sync)
      expect(callCount, 1);

      completer.complete();
      await first;
    });

    test('pulls remote changes for non-dirty files', () async {
      final remoteItem = makeItem('note.md', 'note.md');
      when(() => local.getDirtyPaths()).thenAnswer((_) async => {});
      when(() => git.listDirectory('')).thenAnswer((_) async => [remoteItem]);
      when(() => local.getAllShas()).thenAnswer((_) async => {'note.md': 'oldsha'});
      when(() => git.getFile('note.md'))
          .thenAnswer((_) async => (content: 'remote content', sha: 'sha-note.md'));
      when(() => local.writeNote('note.md', 'remote content')).thenAnswer((_) async {});
      when(() => local.setSha('note.md', 'sha-note.md')).thenAnswer((_) async {});

      await sync.sync();

      verify(() => git.getFile('note.md')).called(1);
      verify(() => local.writeNote('note.md', 'remote content')).called(1);
    });
  });
}
