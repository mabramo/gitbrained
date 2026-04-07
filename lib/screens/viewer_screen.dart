import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../models/note.dart';
import '../services/interfaces.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/loading_view.dart';
import 'editor_screen.dart';

class ViewerScreen extends StatefulWidget {
  final String path;

  const ViewerScreen({super.key, required this.path});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  bool _initialized = false;
  late IGitService _git;
  late ILocalStorageService _local;

  Note? _note;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _git = context.read<IGitService>();
      _local = context.read<ILocalStorageService>();
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      Note? note = await _local.readNote(widget.path);

      if (note == null) {
        final (:content, :sha) = await _git.getFile(widget.path);
        await _local.writeNote(widget.path, content);
        await _local.setSha(widget.path, sha);
        note = Note(
          path: widget.path,
          content: content,
          remoteSha: sha,
          lastModified: DateTime.now(),
        );
      }

      if (mounted) setState(() { _note = note; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _openEditor() async {
    if (_note == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(note: _note!),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filename = widget.path.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: Text(filename),
        actions: [
          if (_note?.isDirty ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.circle,
                size: 8,
                color: theme.colorScheme.primary,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: _loading ? null : _openEditor,
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _note == null
              ? Center(
                  child: Text(
                    'Could not load note.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                )
              : GestureDetector(
                  onDoubleTap: _openEditor,
                  child: Markdown(
                    data: _note!.content,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    styleSheet: _buildStyleSheet(theme),
                    selectable: true,
                  ),
                ),
    );
  }

  MarkdownStyleSheet _buildStyleSheet(ThemeData theme) {
    final cs = theme.colorScheme;

    return MarkdownStyleSheet(
      h1: interStyle(fontSize: 26, fontWeight: FontWeight.w700, color: cs.onSurface, height: 1.3),
      h2: interStyle(fontSize: 21, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.3),
      h3: interStyle(fontSize: 17, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.4),
      p: interStyle(fontSize: 15, color: cs.onSurface, height: 1.65),
      code: monoStyle(
        fontSize: 13,
        backgroundColor: cs.surfaceContainerHighest,
        color: cs.primary,
      ),
      codeblockDecoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
      blockquote: interStyle(
        fontSize: 15,
        color: cs.onSurfaceVariant,
        fontStyle: FontStyle.italic,
        height: 1.65,
      ),
      tableHead: interStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
      tableBody: interStyle(color: cs.onSurface, height: 1.5),
      tableBorder: TableBorder.all(color: cs.outlineVariant, width: 0.5),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      listBullet: interStyle(fontSize: 15, color: cs.onSurfaceVariant),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
    );
  }
}
