class Note {
  final String path;
  final String content;
  final String? remoteSha; // last known SHA from API, null if new
  final bool isDirty;
  final DateTime lastModified;

  const Note({
    required this.path,
    required this.content,
    this.remoteSha,
    this.isDirty = false,
    required this.lastModified,
  });

  String get filename => path.split('/').last;

  bool get isNew => remoteSha == null;

  Note copyWith({
    String? content,
    String? remoteSha,
    bool? isDirty,
    DateTime? lastModified,
  }) {
    return Note(
      path: path,
      content: content ?? this.content,
      remoteSha: remoteSha ?? this.remoteSha,
      isDirty: isDirty ?? this.isDirty,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

enum SyncStatus { idle, syncing, conflict, error }

class SyncState {
  final SyncStatus status;
  final DateTime? lastSync;
  final String? errorMessage;
  final List<String> conflicts;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSync,
    this.errorMessage,
    this.conflicts = const [],
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSync,
    String? errorMessage,
    List<String>? conflicts,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSync: lastSync ?? this.lastSync,
      errorMessage: errorMessage ?? this.errorMessage,
      conflicts: conflicts ?? this.conflicts,
    );
  }
}
