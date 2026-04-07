import 'package:flutter/material.dart';

class MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  void _insert(String prefix, String suffix, String placeholder) {
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid) {
      // No valid selection — just append at end
      final newText = text + prefix + placeholder + suffix;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      return;
    }

    final selected = sel.textInside(text);
    final replacement = selected.isEmpty ? placeholder : selected;
    final newText =
        text.replaceRange(sel.start, sel.end, '$prefix$replacement$suffix');
    final cursorPos = sel.start + prefix.length + replacement.length + suffix.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos),
    );
    focusNode.requestFocus();
  }

  void _insertBlock(String block) {
    final text = controller.text;
    final sel = controller.selection;
    final pos = sel.isValid ? sel.start : text.length;

    // Ensure we're on a new line
    final prefix = (pos > 0 && text[pos - 1] != '\n') ? '\n' : '';
    final newText = text.substring(0, pos) + prefix + block + text.substring(pos);
    final cursor = pos + prefix.length + block.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
    focusNode.requestFocus();
  }

  void _insertLinePrefix(String prefix) {
    final text = controller.text;
    final sel = controller.selection;
    final pos = sel.isValid ? sel.start : text.length;

    // Find start of current line
    final lineStart = text.lastIndexOf('\n', pos - 1) + 1;
    final newText = text.substring(0, lineStart) + prefix + text.substring(lineStart);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
    focusNode.requestFocus();
  }

  static const _tableTemplate = '''| Column | Column |
|--------|--------|
|        |        |
''';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withAlpha(120), width: 0.5),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          _btn('H1', () => _insertLinePrefix('# '), theme),
          _btn('H2', () => _insertLinePrefix('## '), theme),
          _btn('H3', () => _insertLinePrefix('### '), theme),
          _divider(cs),
          _iconBtn(Icons.format_bold, () => _insert('**', '**', 'bold'), theme),
          _iconBtn(Icons.format_italic, () => _insert('*', '*', 'italic'), theme),
          _iconBtn(Icons.format_strikethrough, () => _insert('~~', '~~', 'text'), theme),
          _divider(cs),
          _iconBtn(Icons.format_list_bulleted, () => _insertLinePrefix('- '), theme),
          _iconBtn(Icons.format_list_numbered, () => _insertLinePrefix('1. '), theme),
          _iconBtn(Icons.check_box_outlined, () => _insertLinePrefix('- [ ] '), theme),
          _divider(cs),
          _iconBtn(Icons.code, () => _insert('`', '`', 'code'), theme),
          _btn('```', () => _insertBlock('```\n\n```'), theme),
          _divider(cs),
          _iconBtn(Icons.table_chart_outlined, () => _insertBlock(_tableTemplate), theme),
          _btn('---', () => _insertBlock('\n---\n'), theme),
          _iconBtn(Icons.link, () => _insert('[', '](url)', 'text'), theme),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap, ThemeData theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, ThemeData theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _divider(ColorScheme cs) {
    return Container(
      width: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      color: cs.outlineVariant,
    );
  }
}
