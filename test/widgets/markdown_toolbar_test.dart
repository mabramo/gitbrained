import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbrained/widgets/markdown_toolbar.dart';

void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Widget buildToolbar() {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            MarkdownToolbar(controller: controller, focusNode: focusNode),
          ],
        ),
      ),
    );
  }

  Future<void> tapByText(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
  }

  Future<void> tapByIcon(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await tester.pump();
  }

  group('heading buttons', () {
    testWidgets('H1 inserts # prefix', (tester) async {
      controller.value = const TextEditingValue(
        text: 'Hello',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pumpWidget(buildToolbar());
      await tapByText(tester, 'H1');
      expect(controller.text, startsWith('# '));
    });

    testWidgets('H2 inserts ## prefix', (tester) async {
      controller.value = const TextEditingValue(
        text: 'Hello',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pumpWidget(buildToolbar());
      await tapByText(tester, 'H2');
      expect(controller.text, startsWith('## '));
    });

    testWidgets('H3 inserts ### prefix', (tester) async {
      controller.value = const TextEditingValue(
        text: 'Hello',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pumpWidget(buildToolbar());
      await tapByText(tester, 'H3');
      expect(controller.text, startsWith('### '));
    });
  });

  group('inline formatting', () {
    testWidgets('Bold wraps selection in **', (tester) async {
      controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 6, extentOffset: 11),
      );
      await tester.pumpWidget(buildToolbar());
      await tapByIcon(tester, Icons.format_bold);
      expect(controller.text, 'hello **world**');
    });

    testWidgets('Italic wraps selection in *', (tester) async {
      controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 6, extentOffset: 11),
      );
      await tester.pumpWidget(buildToolbar());
      await tapByIcon(tester, Icons.format_italic);
      expect(controller.text, 'hello *world*');
    });

    testWidgets('Strikethrough wraps selection in ~~', (tester) async {
      controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 6, extentOffset: 11),
      );
      await tester.pumpWidget(buildToolbar());
      await tapByIcon(tester, Icons.format_strikethrough);
      expect(controller.text, 'hello ~~world~~');
    });

    testWidgets('Inline code wraps selection in backticks', (tester) async {
      controller.value = const TextEditingValue(
        text: 'run foo',
        selection: TextSelection(baseOffset: 4, extentOffset: 7),
      );
      await tester.pumpWidget(buildToolbar());
      await tapByIcon(tester, Icons.code);
      expect(controller.text, 'run `foo`');
    });
  });

  group('list buttons', () {
    testWidgets('Bullet inserts - prefix', (tester) async {
      controller.value = const TextEditingValue(
        text: 'item',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pumpWidget(buildToolbar());
      await tapByIcon(tester, Icons.format_list_bulleted);
      expect(controller.text, startsWith('- '));
    });

    testWidgets('Numbered inserts 1. prefix', (tester) async {
      controller.value = const TextEditingValue(
        text: 'item',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pumpWidget(buildToolbar());
      await tapByIcon(tester, Icons.format_list_numbered);
      expect(controller.text, startsWith('1. '));
    });

    testWidgets('Checkbox inserts - [ ] prefix', (tester) async {
      controller.value = const TextEditingValue(
        text: 'task',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pumpWidget(buildToolbar());
      await tapByIcon(tester, Icons.check_box_outlined);
      expect(controller.text, startsWith('- [ ] '));
    });
  });

  group('block buttons', () {
    testWidgets('Table inserts table template', (tester) async {
      controller.text = '';
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpWidget(buildToolbar());
      await tapByIcon(tester, Icons.table_chart_outlined);
      expect(controller.text, contains('| Column | Column |'));
      expect(controller.text, contains('|--------|--------|'));
    });
  });

  group('link button', () {
    testWidgets('Link wraps selection in [selection](url)', (tester) async {
      controller.value = const TextEditingValue(
        text: 'click here',
        selection: TextSelection(baseOffset: 6, extentOffset: 10),
      );
      await tester.pumpWidget(buildToolbar());
      await tapByIcon(tester, Icons.link);
      expect(controller.text, 'click [here](url)');
    });
  });
}
