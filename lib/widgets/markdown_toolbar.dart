import 'package:flutter/material.dart';

class MarkdownToolbar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  @override
  State<MarkdownToolbar> createState() => _MarkdownToolbarState();
}

class _MarkdownToolbarState extends State<MarkdownToolbar> {
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final sel = widget.controller.selection;
    if (sel.isValid) _lastSelection = sel;
  }

  // Always returns a valid selection — falls back to last known position.
  TextSelection get _sel {
    final sel = widget.controller.selection;
    return sel.isValid ? sel : _lastSelection;
  }

  // Wraps the current selection (or inserts placeholder) with prefix/suffix.
  void _insert(String prefix, String suffix, String placeholder) {
    final text = widget.controller.text;
    final sel = _sel;
    final selected = sel.textInside(text);
    final replacement = selected.isEmpty ? placeholder : selected;
    final newText =
        text.replaceRange(sel.start, sel.end, '$prefix$replacement$suffix');
    final cursorPos =
        sel.start + prefix.length + replacement.length + suffix.length;
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos),
    );
    widget.focusNode.requestFocus();
  }

  // Inserts a block at the current line, ensuring it starts on a new line.
  // [innerCursorOffset] places the cursor inside the block rather than at end.
  void _insertBlock(String block, {int? innerCursorOffset}) {
    final text = widget.controller.text;
    final pos = _sel.start;
    final prefix = (pos > 0 && text[pos - 1] != '\n') ? '\n' : '';
    final newText =
        text.substring(0, pos) + prefix + block + text.substring(pos);
    final cursor =
        pos + prefix.length + (innerCursorOffset ?? block.length);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
    widget.focusNode.requestFocus();
  }

  // Adds or removes a line-start prefix. For heading prefixes (#, ##, ###),
  // any existing heading on the line is replaced rather than stacked.
  void _insertLinePrefix(String prefix) {
    final text = widget.controller.text;
    final sel = _sel;
    final pos = sel.start;
    final lineStart = pos > 0 ? text.lastIndexOf('\n', pos - 1) + 1 : 0;
    final lineText = text.substring(lineStart);

    // Determine what prefix, if any, already occupies the line start.
    String existingPrefix = '';
    if (prefix.startsWith('#')) {
      // Heading: replace any existing heading level.
      final match = RegExp(r'^#{1,6} ').firstMatch(lineText);
      if (match != null) existingPrefix = match.group(0)!;
    } else if (lineText.startsWith(prefix)) {
      existingPrefix = prefix;
    }

    final String newText;
    final int newCursor;

    if (existingPrefix == prefix) {
      // Same prefix already present — toggle it off.
      newText = text.substring(0, lineStart) +
          text.substring(lineStart + prefix.length);
      newCursor = (pos - prefix.length).clamp(lineStart, newText.length);
    } else {
      // Add new prefix, stripping any conflicting existing prefix.
      newText = text.substring(0, lineStart) +
          prefix +
          text.substring(lineStart + existingPrefix.length);
      final delta = prefix.length - existingPrefix.length;
      newCursor = (pos + delta).clamp(lineStart, newText.length);
    }

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    widget.focusNode.requestFocus();
  }

  static const _tableTemplate = '| Column | Column |\n|--------|--------|\n|        |        |\n';

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
          // innerCursorOffset: 4 puts the cursor on the empty line between the fences
          _btn('```', () => _insertBlock('```\n\n```', innerCursorOffset: 4), theme),
          _divider(cs),
          // innerCursorOffset: 2 puts the cursor inside the first table cell
          _iconBtn(Icons.table_chart_outlined, () => _insertBlock(_tableTemplate, innerCursorOffset: 2), theme),
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
        child: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
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
