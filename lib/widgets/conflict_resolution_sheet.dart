import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/interfaces.dart';
import '../utils/snackbar_helper.dart';

class ConflictResolutionSheet extends StatefulWidget {
  final String path;
  const ConflictResolutionSheet({super.key, required this.path});

  @override
  State<ConflictResolutionSheet> createState() => _ConflictResolutionSheetState();
}

class _ConflictResolutionSheetState extends State<ConflictResolutionSheet> {
  bool _loading = true;
  String? _localContent;
  String? _remoteContent;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _loadBothVersions();
  }

  Future<void> _loadBothVersions() async {
    final local = context.read<ILocalStorageService>();
    final git = context.read<IGitService>();
    try {
      final note = await local.readNote(widget.path);
      final remote = await git.getFile(widget.path);
      final content = remote.content;
      if (mounted) {
        setState(() {
          _localContent = note?.content ?? '';
          _remoteContent = content;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _resolve(Future<void> Function() action) async {
    setState(() => _resolving = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _resolving = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sync = context.read<ISyncService>();
    final filename = widget.path.split('/').last;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, size: 18, color: cs.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filename,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 0),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _versionCard(
                        theme: theme,
                        label: 'Your version',
                        content: _localContent ?? '',
                        color: cs.primaryContainer,
                        labelColor: cs.onPrimaryContainer,
                      ),
                      const SizedBox(height: 12),
                      _versionCard(
                        theme: theme,
                        label: 'Remote version',
                        content: _remoteContent ?? '',
                        color: cs.secondaryContainer,
                        labelColor: cs.onSecondaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 0),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resolving
                          ? null
                          : () => _resolve(() => sync.resolveKeepRemote(widget.path)),
                      child: const Text('Keep remote'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _resolving
                          ? null
                          : () => _resolve(() => sync.resolveKeepLocal(widget.path)),
                      child: _resolving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Keep mine'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _versionCard({
    required ThemeData theme,
    required String label,
    required String content,
    required Color color,
    required Color labelColor,
  }) {
    final preview = content.isEmpty ? '(empty)' : content;
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(60),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withAlpha(100),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              preview,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'JetBrainsMono',
                height: 1.5,
              ),
              maxLines: 20,
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }
}
