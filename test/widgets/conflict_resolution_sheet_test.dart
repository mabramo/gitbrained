import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:gitbrained/models/note.dart';
import 'package:gitbrained/services/interfaces.dart';
import 'package:gitbrained/widgets/conflict_resolution_sheet.dart';
import '../helpers/mock_services.dart';

void main() {
  setUpAll(registerFallbacks);

  late MockGitService git;
  late MockLocalStorageService local;
  late MockSyncService sync;
  late StreamController<SyncState> syncController;

  setUp(() {
    git = MockGitService();
    local = MockLocalStorageService();
    sync = MockSyncService();
    syncController = StreamController<SyncState>.broadcast();

    when(() => sync.stateStream).thenAnswer((_) => syncController.stream);
    when(() => sync.currentState).thenReturn(const SyncState());
  });

  tearDown(() => syncController.close());

  Widget buildSheet(String path) {
    return MultiProvider(
      providers: [
        Provider<IGitService>.value(value: git),
        Provider<ILocalStorageService>.value(value: local),
        Provider<ISyncService>.value(value: sync),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ConflictResolutionSheet(path: path),
        ),
      ),
    );
  }

  testWidgets('shows both versions after loading', (tester) async {
    when(() => local.readNote('notes/a.md')).thenAnswer((_) async => Note(
          path: 'notes/a.md',
          content: 'my local changes',
          lastModified: DateTime.now(),
        ));
    when(() => git.getFile('notes/a.md'))
        .thenAnswer((_) async => (content: 'remote changes', sha: 'sha1'));

    await tester.pumpWidget(buildSheet('notes/a.md'));
    await tester.pump();

    expect(find.text('Your version'), findsOneWidget);
    expect(find.text('Remote version'), findsOneWidget);
    expect(find.textContaining('my local changes'), findsOneWidget);
    expect(find.textContaining('remote changes'), findsOneWidget);
  });

  testWidgets('Keep mine calls resolveKeepLocal', (tester) async {
    when(() => local.readNote('notes/a.md')).thenAnswer((_) async => Note(
          path: 'notes/a.md',
          content: 'local',
          lastModified: DateTime.now(),
        ));
    when(() => git.getFile('notes/a.md'))
        .thenAnswer((_) async => (content: 'remote', sha: 'sha1'));
    when(() => sync.resolveKeepLocal('notes/a.md')).thenAnswer((_) async {});

    await tester.pumpWidget(buildSheet('notes/a.md'));
    await tester.pump();

    await tester.tap(find.text('Keep mine'));
    await tester.pump();

    verify(() => sync.resolveKeepLocal('notes/a.md')).called(1);
  });

  testWidgets('Keep remote calls resolveKeepRemote', (tester) async {
    when(() => local.readNote('notes/a.md')).thenAnswer((_) async => Note(
          path: 'notes/a.md',
          content: 'local',
          lastModified: DateTime.now(),
        ));
    when(() => git.getFile('notes/a.md'))
        .thenAnswer((_) async => (content: 'remote', sha: 'sha1'));
    when(() => sync.resolveKeepRemote('notes/a.md')).thenAnswer((_) async {});

    await tester.pumpWidget(buildSheet('notes/a.md'));
    await tester.pump();

    await tester.tap(find.text('Keep remote'));
    await tester.pump();

    verify(() => sync.resolveKeepRemote('notes/a.md')).called(1);
  });
}
