import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import '../utils/error_handler.dart';
import 'interfaces.dart';

class LocalStorageService implements ILocalStorageService {
  static const _shaFile = '.meta/shas.json';
  static const _dirtyFile = '.meta/dirty.json';

  final String? _overridePath;
  late Directory _root;

  LocalStorageService({String? overridePath}) : _overridePath = overridePath;

  @override
  Future<void> init() async {
    if (_overridePath != null) {
      _root = Directory('$_overridePath/repo');
    } else {
      final docs = await getApplicationDocumentsDirectory();
      _root = Directory('${docs.path}/repo');
    }
    await _root.create(recursive: true);
    await Directory('${_root.path}/.meta').create(recursive: true);
  }

  @override
  Future<Note?> readNote(String repoPath) async {
    try {
      final file = File('${_root.path}/$repoPath');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final sha = await _getSha(repoPath);
      final dirty = await _isDirty(repoPath);
      return Note(
        path: repoPath,
        content: content,
        remoteSha: sha,
        isDirty: dirty,
        lastModified: await file.lastModified(),
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> writeNote(String repoPath, String content) async {
    try {
      final file = File('${_root.path}/$repoPath');
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<bool> noteExists(String repoPath) async {
    return File('${_root.path}/$repoPath').exists();
  }

  @override
  Future<List<FileSystemEntity>> listLocal(String dirPath) async {
    try {
      final dir = Directory('${_root.path}/$dirPath');
      if (!await dir.exists()) return [];
      return dir
          .listSync()
          .where((e) => !e.path.contains('/.meta'))
          .toList()
        ..sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return a.path.compareTo(b.path);
        });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<Map<String, String>> _loadShas() async {
    final file = File('${_root.path}/$_shaFile');
    if (!await file.exists()) return {};
    final raw = await file.readAsString();
    return Map<String, String>.from(jsonDecode(raw));
  }

  Future<void> _saveShas(Map<String, String> shas) async {
    final file = File('${_root.path}/$_shaFile');
    await file.writeAsString(jsonEncode(shas));
  }

  Future<String?> _getSha(String repoPath) async {
    final shas = await _loadShas();
    return shas[repoPath];
  }

  @override
  Future<void> setSha(String repoPath, String sha) async {
    try {
      final shas = await _loadShas();
      shas[repoPath] = sha;
      await _saveShas(shas);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<Map<String, String>> getAllShas() async {
    try {
      return await _loadShas();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<Set<String>> _loadDirty() async {
    final file = File('${_root.path}/$_dirtyFile');
    if (!await file.exists()) return {};
    final raw = await file.readAsString();
    return Set<String>.from(jsonDecode(raw));
  }

  Future<void> _saveDirty(Set<String> dirty) async {
    final file = File('${_root.path}/$_dirtyFile');
    await file.writeAsString(jsonEncode(dirty.toList()));
  }

  Future<bool> _isDirty(String repoPath) async {
    final dirty = await _loadDirty();
    return dirty.contains(repoPath);
  }

  @override
  Future<void> markDirty(String repoPath) async {
    try {
      final dirty = await _loadDirty();
      dirty.add(repoPath);
      await _saveDirty(dirty);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> clearDirty(String repoPath) async {
    try {
      final dirty = await _loadDirty();
      dirty.remove(repoPath);
      await _saveDirty(dirty);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<Set<String>> getDirtyPaths() async {
    try {
      return await _loadDirty();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
