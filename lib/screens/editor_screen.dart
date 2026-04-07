import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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

      _controller.addListener(() {
        if (!_dirty && _controller.text != (widget.note?.content ?? '')) {
          setState(() => _dirty = true);
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

  Future<void> _promptNewFilename() async {
    final subdir = _config.subdir;
    String filename = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('New note'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Filename',
              hintText: 'my-note.md',
              suffixText: subdir.isNotEmpty ? '  in /$subdir' : '',
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
        );
      },
    );

    if (filename.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (!filename.endsWith('.md')) filename += '.md';
    final base = subdir.isNotEmpty ? subdir : '';
    _path = base.isNotEmpty ? '$base/$filename' : filename;
    setState(() {});
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
                style: GoogleFonts.jetBrainsMono(
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
