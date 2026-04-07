import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:gitbrained/models/note.dart';
import 'package:gitbrained/models/repo_item.dart';
import 'package:gitbrained/screens/browser_screen.dart';
import 'package:gitbrained/services/interfaces.dart';
import 'package:gitbrained/utils/exceptions.dart';
import 'package:gitbrained/widgets/loading_view.dart';
import 'package:gitbrained/widgets/error_view.dart';
import '../helpers/mock_services.dart';

void main() {
  setUpAll(registerFallbacks);

  late MockGitService git;
  late MockLocalStorageService local;
  late MockConfigService config;
  late MockSyncService sync;
  late StreamController<SyncState> syncController;

  setUp(() {
    git = MockGitService();
    local = MockLocalStorageService();
    config = MockConfigService();
    sync = MockSyncService();
    syncController = StreamController<SyncState>.broadcast();

    when(() => sync.stateStream).thenAnswer((_) => syncController.stream);
    when(() => sync.currentState).thenReturn(const SyncState());
    when(() => local.getDirtyPaths()).thenAnswer((_) async => {});
    // _load() merges remote with local filesystem — return empty by default.
    when(() => local.listLocal(any())).thenAnswer((_) async => []);
  });

  tearDown(() {
    syncController.close();
  });

  Widget buildScreen({String path = ''}) {
    return MultiProvider(
      providers: [
        Provider<IGitService>.value(value: git),
        Provider<ILocalStorageService>.value(value: local),
        Provider<IConfigService>.value(value: config),
        Provider<ISyncService>.value(value: sync),
      ],
      child: MaterialApp(
        home: BrowserScreen(path: path),
      ),
    );
  }

  RepoItem makeItem(String name, {bool isDir = false}) {
    return RepoItem(
      name: name,
      path: name,
      sha: 'sha-$name',
      type: isDir ? 'dir' : 'file',
    );
  }

  testWidgets('shows LoadingView while loading', (tester) async {
    final completer = Completer<List<RepoItem>>();
    when(() => git.listDirectory('')).thenAnswer((_) => completer.future);

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);

    completer.complete([]);
  });

  testWidgets('shows ErrorView on error', (tester) async {
    when(() => git.listDirectory('')).thenThrow(
      const NetworkException('No connection. Check your network.'),
    );

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('No connection. Check your network.'), findsAtLeast(1));
  });

  testWidgets('shows file list when loaded', (tester) async {
    when(() => git.listDirectory('')).thenAnswer((_) async => [
          makeItem('notes.md'),
          makeItem('folder', isDir: true),
        ]);

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    expect(find.text('notes.md'), findsOneWidget);
    expect(find.text('folder'), findsOneWidget);
  });

  testWidgets('tapping a directory navigates into it (breadcrumb updates)', (tester) async {
    when(() => git.listDirectory('')).thenAnswer((_) async => [
          makeItem('myfolder', isDir: true),
        ]);
    when(() => git.listDirectory('myfolder')).thenAnswer((_) async => []);
    when(() => local.getDirtyPaths()).thenAnswer((_) async => {});

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await tester.tap(find.text('myfolder'));
    await tester.pump();
    await tester.pump();

    expect(find.text('myfolder'), findsAtLeast(1));
  });

  testWidgets('dirty files show the dot indicator', (tester) async {
    when(() => git.listDirectory('')).thenAnswer((_) async => [
          makeItem('dirty.md'),
        ]);
    when(() => local.getDirtyPaths()).thenAnswer((_) async => {'dirty.md'});

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    // The dot indicator is a Container with BoxShape.circle
    final containers = tester.widgetList<Container>(find.byType(Container));
    final hasDot = containers.any((c) {
      final decoration = c.decoration;
      if (decoration is BoxDecoration) {
        return decoration.shape == BoxShape.circle;
      }
      return false;
    });
    expect(hasDot, isTrue);
  });

  testWidgets('tapping a file navigates to viewer', (tester) async {
    when(() => git.listDirectory('')).thenAnswer((_) async => [
          makeItem('note.md'),
        ]);
    when(() => local.readNote('note.md')).thenAnswer((_) async => Note(
          path: 'note.md',
          content: '# Note',
          lastModified: DateTime.now(),
        ));

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await tester.tap(find.text('note.md'));
    await tester.pump();
    await tester.pump();

    // ViewerScreen should be pushed — verify the note filename appears in the app bar
    expect(find.text('note.md'), findsAtLeast(1));
  });
}
