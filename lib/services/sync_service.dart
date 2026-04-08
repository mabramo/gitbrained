import 'dart:async';
import '../models/note.dart';
import '../utils/exceptions.dart';
import 'interfaces.dart';

class SyncService implements ISyncService {
  final IConfigService _config;
  final IGitService _git;
  final ILocalStorageService _local;

  final _stateController = StreamController<SyncState>.broadcast();
  @override
  Stream<SyncState> get stateStream => _stateController.stream;

  SyncState _state = const SyncState();
  @override
  SyncState get currentState => _state;

  Timer? _timer;

  SyncService(this._config, this._git, this._local);

  @override
  void startTimer() {
    _timer?.cancel();
    final interval = Duration(minutes: _config.syncIntervalMinutes);
    _timer = Timer.periodic(interval, (_) => sync());
  }

  @override
  void restartTimer() {
    startTimer();
  }

  @override
  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> sync() async {
    if (_state.status == SyncStatus.syncing) return;
    _emit(_state.copyWith(status: SyncStatus.syncing));

    final conflicts = <String>[];

    try {
      final dirtyPaths = await _local.getDirtyPaths();
      for (final path in dirtyPaths) {
        final note = await _local.readNote(path);
        if (note == null) continue;
        try {
          final newSha = await _git.createOrUpdateFile(
            path: path,
            content: note.content,
            sha: note.remoteSha,
          );
          await _local.setSha(path, newSha);
          await _local.clearDirty(path);
        } on ConflictException {
          conflicts.add(path);
        }
      }

      await _pullDirectory('');
    } catch (e) {
      _emit(_state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      ));
      return;
    }

    _emit(_state.copyWith(
      status: conflicts.isEmpty ? SyncStatus.idle : SyncStatus.conflict,
      lastSync: DateTime.now(),
      conflicts: conflicts,
      errorMessage: null,
    ));
  }

  Future<void> _pullDirectory(String path) async {
    final items = await _git.listDirectory(path);
    final localShas = await _local.getAllShas();
    final dirtyPaths = await _local.getDirtyPaths();

    for (final item in items) {
      if (item.isDir) {
        await _pullDirectory(item.path);
      } else if (item.isMarkdown) {
        final localSha = localShas[item.path];
        final isDirty = dirtyPaths.contains(item.path);

        if (isDirty) continue;

        if (localSha != item.sha) {
          final (:content, :sha) = await _git.getFile(item.path);
          await _local.writeNote(item.path, content);
          await _local.setSha(item.path, sha);
        }
      }
    }
  }

  @override
  Future<void> resolveKeepLocal(String path) async {
    final note = await _local.readNote(path);
    if (note == null) return;
    // Fetch current remote SHA so the update doesn't conflict.
    final remote = await _git.getFile(path);
    final remoteSha = remote.sha;
    final newSha = await _git.createOrUpdateFile(
      path: path,
      content: note.content,
      sha: remoteSha,
    );
    await _local.setSha(path, newSha);
    await _local.clearDirty(path);
    _removeConflict(path);
  }

  @override
  Future<void> resolveKeepRemote(String path) async {
    final (:content, :sha) = await _git.getFile(path);
    await _local.writeNote(path, content);
    await _local.setSha(path, sha);
    await _local.clearDirty(path);
    _removeConflict(path);
  }

  void _removeConflict(String path) {
    final remaining = _state.conflicts.where((p) => p != path).toList();
    _emit(_state.copyWith(
      conflicts: remaining,
      status: remaining.isEmpty ? SyncStatus.idle : SyncStatus.conflict,
    ));
  }

  void _emit(SyncState state) {
    _state = state;
    _stateController.add(state);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stateController.close();
  }
}
