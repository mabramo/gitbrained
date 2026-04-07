import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../models/note.dart';
import '../services/interfaces.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/markdown_toolbar.dart';

class EditorScreen extends StatefulWidget {
  final Note? note;
  final String? basePath;

  const EditorScreen({super.key, this.note, this.basePath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool _initialized = false;
  late ILocalStorageService _local;
  late IConfigService _config;

  late TextEditingController _controller;
  late FocusNode _focusNode;
  late String _path;
  bool _dirty = false;
  bool _saving = false;
  String _previousText = '';
  bool _handlingAutoList = false;

  bool get _isNew => widget.note == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _local = context.read<ILocalStorageService>();
      _config = context.read<IConfigService>();

      _controller = TextEditingController(text: widget.note?.content ?? '');
      _focusNode = FocusNode();
      _path = widget.note?.path ?? '';
      _previousText = _controller.text;

      _controller.addListener(() {
        final text = _controller.text;
        if (!_dirty && text != (widget.note?.content ?? '')) {
          setState(() => _dirty = true);
        }
        if (!_handlingAutoList) {
          final prev = _previousText;
          _previousText = text;
          _handleAutoList(text, prev);
        }
      });

      if (!_isNew) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
      }

      if (_isNew && _path.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _promptNewFilename());
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _saveLocally() async {
    if (_path.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _local.writeNote(_path, _controller.text);
      await _local.markDirty(_path);
      if (mounted) setState(() { _dirty = false; _saving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _handleAutoList(String text, String previousText) {
    final sel = _controller.selection;
    if (!sel.isCollapsed) return;
    final pos = sel.baseOffset;
    if (pos < 1 || pos > text.length) return;
    // Only act when a single newline was just inserted
    if (text.length != previousText.length + 1) return;
    if (text[pos - 1] != '\n') return;

    // Find the previous line
    final prevLineStart = previousText.lastIndexOf('\n', pos - 2) + 1;
    final prevLine = previousText.substring(prevLineStart, pos - 1);

    // Bullet list: "- ", "* ", "- [ ] ", "- [x] "
    final bulletRe = RegExp(r'^(\s*)([-*]) (\[[ x]\] )?(.*)$');
    final numberedRe = RegExp(r'^(\s*)(\d+)\. (.*)$');

    final bm = bulletRe.firstMatch(prevLine);
    final nm = numberedRe.firstMatch(prevLine);

    TextEditingValue? newValue;

    if (bm != null) {
      final indent = bm.group(1)!;
      final marker = bm.group(2)!;
      final checkbox = bm.group(3);
      final content = bm.group(4)!;
      if (content.isEmpty) {
        final newText = text.substring(0, prevLineStart) + text.substring(pos);
        newValue = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: prevLineStart),
        );
      } else {
        final continuation = checkbox != null ? '$indent$marker [ ] ' : '$indent$marker ';
        final newText = text.substring(0, pos) + continuation + text.substring(pos);
        newValue = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: pos + continuation.length),
        );
      }
    } else if (nm != null) {
      final indent = nm.group(1)!;
      final num = int.parse(nm.group(2)!);
      final content = nm.group(3)!;
      if (content.isEmpty) {
        final newText = text.substring(0, prevLineStart) + text.substring(pos);
        newValue = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: prevLineStart),
        );
      } else {
        final continuation = '$indent${num + 1}. ';
        final newText = text.substring(0, pos) + continuation + text.substring(pos);
        newValue = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: pos + continuation.length),
        );
      }
    }

    if (newValue != null) {
      _handlingAutoList = true;
      _controller.value = newValue;
      _previousText = newValue.text;
      _handlingAutoList = false;
    }
  }

  Future<void> _promptNewFilename() async {
    // Use current browser dir if provided, otherwise fall back to configured subdir
    final basePath = widget.basePath;
    final effectiveBase = (basePath != null && basePath.isNotEmpty)
        ? basePath
        : _config.subdir;

    String filename = '';
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('New note'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Filename',
            hintText: 'my-note.md',
            suffixText: effectiveBase.isNotEmpty ? '  in /$effectiveBase' : '',
          ),
          onChanged: (v) => filename = v,
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(ctx).pop(); filename = ''; },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    // Defer disposal until after the dialog's exit animation completes.
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());

    if (filename.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (!filename.endsWith('.md')) filename += '.md';
    setState(() {
      _path = effectiveBase.isNotEmpty ? '$effectiveBase/$filename' : filename;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filename = _path.isEmpty ? 'New note' : _path.split('/').last;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard()) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(filename),
          actions: [
            if (_dirty)
              Padding(
                padding: const EdgeInsets.only(right: 4, top: 16),
                child: Text(
                  'edited',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              tooltip: 'Save to device',
              onPressed: (_saving || !_dirty || _path.isEmpty)
                  ? null
                  : _saveLocally,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: monoStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: InputBorder.none,
                  hintText: _path.isEmpty ? '' : 'Start writing…',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                ),
              ),
            ),
            MarkdownToolbar(controller: _controller, focusNode: _focusNode),
          ],
        ),
      ),
    );
  }
}
