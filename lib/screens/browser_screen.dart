import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/repo_item.dart';
import '../services/interfaces.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'viewer_screen.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

class BrowserScreen extends StatefulWidget {
  final String path;
  const BrowserScreen({super.key, required this.path});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  bool _initialized = false;
  late IGitService _git;
  late ILocalStorageService _local;
  late ISyncService _sync;

  late String _currentPath;
  List<RepoItem> _items = [];
  Set<String> _dirtyPaths = {};
  bool _loading = true;
  String? _error;
  StreamSubscription<SyncState>? _syncSub;
  SyncState _syncState = const SyncState();
  bool _fabExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _git = context.read<IGitService>();
      _local = context.read<ILocalStorageService>();
      _sync = context.read<ISyncService>();
      _currentPath = widget.path;
      _syncSub = _sync.stateStream.listen((s) {
        if (mounted) setState(() => _syncState = s);
      });
      _load();
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _git.listDirectory(_currentPath);
      final dirty = await _local.getDirtyPaths();
      if (mounted) {
        setState(() {
          _items = items;
          _dirtyPaths = dirty;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is Exception ? e.toString() : 'Something went wrong. Try again.';
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showErrorSnackBar(context, e);
        });
      }
    }
  }

  void _navigateTo(String path) {
    setState(() => _currentPath = path);
    _load();
  }

  Future<void> _openFile(RepoItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ViewerScreen(path: item.path)),
    );
    _load();
  }

  void _toggleFab() => setState(() => _fabExpanded = !_fabExpanded);

  Future<void> _newNote() async {
    setState(() => _fabExpanded = false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(basePath: _currentPath),
      ),
    );
    _load();
  }

  Future<void> _newFolder() async {
    setState(() => _fabExpanded = false);
    String folderName = '';
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('New folder'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'folder-name'),
            onChanged: (v) => folderName = v.trim(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
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

    if (folderName.isEmpty) return;
    final path = _currentPath.isEmpty ? folderName : '$_currentPath/$folderName';
    try {
      await _local.createFolder(path);
      _load();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _triggerSync() async {
    await _sync.sync();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gitbrained'),
        actions: [
          _syncIcon(theme),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          BreadcrumbBar(
            path: _currentPath,
            onTap: _navigateTo,
          ),
          if (_syncState.conflicts.isNotEmpty)
            _conflictBanner(cs),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? _emptyView(theme)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (context, index) => const Divider(height: 0),
                              itemBuilder: (_, i) => _itemTile(_items[i], theme),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_fabExpanded) ...[
            _miniFab(
              icon: Icons.description_outlined,
              label: 'New note',
              onTap: _newNote,
            ),
            const SizedBox(height: 12),
            _miniFab(
              icon: Icons.folder_outlined,
              label: 'New folder',
              onTap: _newFolder,
            ),
            const SizedBox(height: 16),
          ],
          FloatingActionButton(
            onPressed: _toggleFab,
            tooltip: _fabExpanded ? 'Close' : 'New',
            child: AnimatedRotation(
              turns: _fabExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(RepoItem item, ThemeData theme) {
    final isDirty = _dirtyPaths.contains(item.path);
    final isDir = item.isDir;

    return ListTile(
      leading: Icon(
        isDir ? Icons.folder_outlined : Icons.description_outlined,
        size: 20,
        color: isDir
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isDir ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          if (isDirty)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      trailing: isDir
          ? Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.outlineVariant)
          : null,
      onTap: () => isDir ? _navigateTo(item.path) : _openFile(item),
    );
  }

  Widget _syncIcon(ThemeData theme) {
    final cs = theme.colorScheme;
    switch (_syncState.status) {
      case SyncStatus.syncing:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.onSurfaceVariant,
            ),
          ),
        );
      case SyncStatus.error:
        return IconButton(
          icon: Icon(Icons.sync_problem_outlined, color: cs.error),
          tooltip: _syncState.errorMessage,
          onPressed: _triggerSync,
        );
      case SyncStatus.conflict:
        return IconButton(
          icon: Icon(Icons.warning_amber_outlined, color: cs.error),
          tooltip: 'Conflicts detected',
          onPressed: _triggerSync,
        );
      case SyncStatus.idle:
        return IconButton(
          icon: const Icon(Icons.sync_outlined),
          tooltip: _syncState.lastSync != null
              ? 'Last sync: ${_formatTime(_syncState.lastSync!)}'
              : 'Sync now',
          onPressed: _triggerSync,
        );
    }
  }

  Widget _conflictBanner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      color: cs.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Conflicts: ${_syncState.conflicts.join(', ')}',
        style: TextStyle(color: cs.onErrorContainer, fontSize: 12),
      ),
    );
  }

  Widget _emptyView(ThemeData theme) {
    return Center(
      child: Text(
        'No files here.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Widget _miniFab({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 10),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }
}
