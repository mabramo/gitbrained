import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:gitbrained/app.dart';
import 'package:gitbrained/models/note.dart';
import 'package:gitbrained/services/interfaces.dart';
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
    when(() => sync.sync()).thenAnswer((_) async {});
    when(() => git.listDirectory(any())).thenAnswer((_) async => []);
    when(() => local.listLocal(any())).thenAnswer((_) async => []);
    when(() => local.getDirtyPaths()).thenAnswer((_) async => {});
  });

  tearDown(() => syncController.close());

  Widget buildApp({required bool isConfigured, SyncState syncState = const SyncState()}) {
    when(() => sync.currentState).thenReturn(syncState);
    // SettingsScreen reads these on first build when not configured.
    when(() => config.apiBaseUrl).thenReturn('');
    when(() => config.ownerRepo).thenReturn('');
    when(() => config.branch).thenReturn('');
    when(() => config.subdir).thenReturn('');
    when(() => config.syncIntervalMinutes).thenReturn(10);
    when(() => config.getPat()).thenAnswer((_) async => null);
    return MultiProvider(
      providers: [
        Provider<IGitService>.value(value: git),
        Provider<ILocalStorageService>.value(value: local),
        Provider<IConfigService>.value(value: config),
        Provider<ISyncService>.value(value: sync),
      ],
      child: GitbrainedApp(isConfigured: isConfigured),
    );
  }

  group('foreground-resume sync', () {
    testWidgets('syncs on resume when lastSync is null', (tester) async {
      await tester.pumpWidget(buildApp(isConfigured: true));
      await tester.pump();

      clearInteractions(sync);
      when(() => sync.currentState).thenReturn(const SyncState());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verify(() => sync.sync()).called(1);
    });

    testWidgets('syncs on resume when lastSync is older than threshold', (tester) async {
      final staleState = SyncState(lastSync: DateTime.now().subtract(const Duration(minutes: 10)));
      await tester.pumpWidget(buildApp(isConfigured: true, syncState: staleState));
      await tester.pump();

      clearInteractions(sync);
      when(() => sync.currentState).thenReturn(staleState);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verify(() => sync.sync()).called(1);
    });

    testWidgets('does not sync on resume when lastSync is recent', (tester) async {
      final freshState = SyncState(lastSync: DateTime.now().subtract(const Duration(seconds: 30)));
      await tester.pumpWidget(buildApp(isConfigured: true, syncState: freshState));
      await tester.pump();

      clearInteractions(sync);
      when(() => sync.currentState).thenReturn(freshState);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verifyNever(() => sync.sync());
    });

    testWidgets('does not sync on resume when not configured', (tester) async {
      await tester.pumpWidget(buildApp(isConfigured: false));
      await tester.pump();

      clearInteractions(sync);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      verifyNever(() => sync.sync());
    });

    testWidgets('does not sync on pause', (tester) async {
      await tester.pumpWidget(buildApp(isConfigured: true));
      await tester.pump();

      clearInteractions(sync);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      verifyNever(() => sync.sync());
    });
  });
}
