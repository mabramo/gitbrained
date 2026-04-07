import 'dart:io';
import '../models/note.dart';
import '../models/repo_item.dart';

abstract class IConfigService {
  Future<void> init();
  Future<String?> getPat();
  Future<void> setPat(String value);
  String get apiBaseUrl;
  String get ownerRepo;
  String get branch;
  String get subdir;
  int get syncIntervalMinutes;
  Future<void> setApiBaseUrl(String v);
  Future<void> setOwnerRepo(String v);
  Future<void> setBranch(String v);
  Future<void> setSubdir(String v);
  Future<void> setSyncIntervalMinutes(int v);
  bool get isConfigured;
  String get owner;
  String get repo;
}

abstract class ILocalStorageService {
  Future<void> init();
  Future<Note?> readNote(String repoPath);
  Future<void> writeNote(String repoPath, String content);
  Future<bool> noteExists(String repoPath);
  Future<List<FileSystemEntity>> listLocal(String dirPath);
  Future<void> setSha(String repoPath, String sha);
  Future<Map<String, String>> getAllShas();
  Future<void> markDirty(String repoPath);
  Future<void> clearDirty(String repoPath);
  Future<Set<String>> getDirtyPaths();
  Future<void> createFolder(String repoPath);
}

abstract class IGitService {
  Future<void> init();
  Future<void> refreshAuth();
  Future<List<RepoItem>> listDirectory(String path);
  Future<({String content, String sha})> getFile(String path);
  Future<String> createOrUpdateFile({
    required String path,
    required String content,
    String? sha,
    String? commitMessage,
  });
  Future<void> deleteFile({
    required String path,
    required String sha,
    String? commitMessage,
  });
}

abstract class ISyncService {
  Stream<SyncState> get stateStream;
  SyncState get currentState;
  Future<void> sync();
  void startTimer();
  void restartTimer();
  void stopTimer();
  void dispose();
}
