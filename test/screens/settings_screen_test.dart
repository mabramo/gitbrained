import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:gitbrained/screens/settings_screen.dart';
import 'package:gitbrained/services/interfaces.dart';
import '../helpers/mock_services.dart';

void main() {
  late MockConfigService config;
  late MockGitService git;
  late MockSyncService sync;
  late MockLocalStorageService local;

  setUp(() {
    config = MockConfigService();
    git = MockGitService();
    sync = MockSyncService();
    local = MockLocalStorageService();

    when(() => config.apiBaseUrl).thenReturn('https://api.github.com');
    when(() => config.ownerRepo).thenReturn('');
    when(() => config.branch).thenReturn('main');
    when(() => config.subdir).thenReturn('');
    when(() => config.syncIntervalMinutes).thenReturn(10);
    when(() => config.getPat()).thenAnswer((_) async => null);
  });

  Widget buildScreen({bool isFirstLaunch = false}) {
    return MultiProvider(
      providers: [
        Provider<IConfigService>.value(value: config),
        Provider<IGitService>.value(value: git),
        Provider<ISyncService>.value(value: sync),
        Provider<ILocalStorageService>.value(value: local),
      ],
      child: MaterialApp(
        home: SettingsScreen(isFirstLaunch: isFirstLaunch),
      ),
    );
  }

  final saveButton = find.byKey(const Key('save_button'));

  Future<void> tapSaveButton(WidgetTester tester) async {
    // Scroll the list to the bottom to reveal the save button
    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
    }
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pump();
  }

  group('form validation', () {
    testWidgets('validates owner/repo format', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      final ownerRepoField = find.widgetWithText(TextFormField, 'Owner / Repo');
      await tester.enterText(ownerRepoField, 'invalidformat');

      await tapSaveButton(tester);
      // Scroll back to top to see validation errors
      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, 200));
        await tester.pump();
      }

      expect(find.text('Enter as owner/repo'), findsOneWidget);
    });

    testWidgets('validates required branch field', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      final ownerRepoField = find.widgetWithText(TextFormField, 'Owner / Repo');
      await tester.enterText(ownerRepoField, 'owner/repo');

      final branchField = find.widgetWithText(TextFormField, 'Branch');
      await tester.enterText(branchField, '');

      await tapSaveButton(tester);
      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, 200));
        await tester.pump();
      }

      expect(find.text('Required'), findsAtLeast(1));
    });

    testWidgets('validates required API URL field', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      final ownerRepoField = find.widgetWithText(TextFormField, 'Owner / Repo');
      await tester.enterText(ownerRepoField, 'owner/repo');

      // Scroll to API URL field
      for (var i = 0; i < 2; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pump();
      }

      final apiUrlField = find.widgetWithText(TextFormField, 'API base URL');
      await tester.enterText(apiUrlField, '');

      await tapSaveButton(tester);

      expect(find.text('Required'), findsAtLeast(1));
    });
  });

  group('save behavior', () {
    testWidgets('save button calls setters with correct values', (tester) async {
      when(() => config.setApiBaseUrl(any())).thenAnswer((_) async {});
      when(() => config.setOwnerRepo(any())).thenAnswer((_) async {});
      when(() => config.setBranch(any())).thenAnswer((_) async {});
      when(() => config.setSubdir(any())).thenAnswer((_) async {});
      when(() => config.setSyncIntervalMinutes(any())).thenAnswer((_) async {});
      when(() => git.refreshAuth()).thenAnswer((_) async {});
      when(() => sync.restartTimer()).thenReturn(null);

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      final ownerRepoField = find.widgetWithText(TextFormField, 'Owner / Repo');
      await tester.enterText(ownerRepoField, 'myowner/myrepo');

      await tapSaveButton(tester);
      await tester.pump();

      verify(() => config.setOwnerRepo('myowner/myrepo')).called(1);
    });

    testWidgets('save button is disabled while saving', (tester) async {
      when(() => config.setApiBaseUrl(any())).thenAnswer((_) async {});
      when(() => config.setOwnerRepo(any())).thenAnswer((_) async {});
      when(() => config.setBranch(any())).thenAnswer((_) async {});
      when(() => config.setSubdir(any())).thenAnswer((_) async {});
      when(() => config.setSyncIntervalMinutes(any())).thenAnswer((_) async {});
      when(() => git.refreshAuth())
          .thenAnswer((_) async => await Future.delayed(const Duration(seconds: 1)));
      when(() => sync.restartTimer()).thenReturn(null);

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      final ownerRepoField = find.widgetWithText(TextFormField, 'Owner / Repo');
      await tester.enterText(ownerRepoField, 'owner/repo');

      await tapSaveButton(tester);

      // While saving (delayed), the button should be disabled
      final button = tester.widget<FilledButton>(saveButton);
      expect(button.onPressed, isNull);

      // Advance time so the pending timer completes
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
