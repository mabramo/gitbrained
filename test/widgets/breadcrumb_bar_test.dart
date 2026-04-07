import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbrained/widgets/breadcrumb_bar.dart';

void main() {
  Widget buildBar(String path, void Function(String) onTap) {
    return MaterialApp(
      home: Scaffold(
        body: BreadcrumbBar(path: path, onTap: onTap),
      ),
    );
  }

  testWidgets('renders "root" for empty path', (tester) async {
    await tester.pumpWidget(buildBar('', (_) {}));
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('renders correct segments for nested path', (tester) async {
    await tester.pumpWidget(buildBar('folder/subfolder/file.md', (_) {}));
    expect(find.text('root'), findsOneWidget);
    expect(find.text('folder'), findsOneWidget);
    expect(find.text('subfolder'), findsOneWidget);
    expect(find.text('file.md'), findsOneWidget);
  });

  testWidgets('tapping a non-last segment calls onTap with correct path', (tester) async {
    String? tapped;
    await tester.pumpWidget(buildBar('folder/subfolder', (p) => tapped = p));
    await tester.tap(find.text('folder'));
    await tester.pump();
    expect(tapped, 'folder');
  });

  testWidgets('tapping root when not last calls onTap with empty string', (tester) async {
    String? tapped;
    await tester.pumpWidget(buildBar('folder', (p) => tapped = p));
    await tester.tap(find.text('root'));
    await tester.pump();
    expect(tapped, '');
  });

  testWidgets('last segment is not tappable', (tester) async {
    String? tapped;
    await tester.pumpWidget(buildBar('folder/last', (p) => tapped = p));
    await tester.tap(find.text('last'));
    await tester.pump();
    expect(tapped, isNull);
  });

  testWidgets('root segment is not tappable when path is empty', (tester) async {
    String? tapped;
    await tester.pumpWidget(buildBar('', (p) => tapped = p));
    await tester.tap(find.text('root'));
    await tester.pump();
    expect(tapped, isNull);
  });
}
