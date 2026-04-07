import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/repo_item.dart';
import '../utils/error_handler.dart';
import 'config_service.dart';
import 'interfaces.dart';

class GitService implements IGitService {
  final ConfigService _config;
  final Dio Function(BaseOptions) _dioFactory;
  late Dio _dio;

  GitService(this._config, {Dio Function(BaseOptions)? dioFactory})
      : _dioFactory = dioFactory ?? ((opts) => Dio(opts));

  @override
  Future<void> init() async {
    final pat = await _config.getPat();
    _dio = _dioFactory(BaseOptions(
      baseUrl: _config.apiBaseUrl,
      headers: {
        'Authorization': 'Bearer $pat',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  @override
  Future<void> refreshAuth() => init();

  String get _repoBase =>
      '/repos/${_config.owner}/${_config.repo}/contents';

  @override
  Future<List<RepoItem>> listDirectory(String path) async {
    try {
      final url = path.isEmpty ? _repoBase : '$_repoBase/$path';
      final resp = await _dio.get<List<dynamic>>(
        url,
        queryParameters: {'ref': _config.branch},
      );
      return (resp.data ?? [])
          .cast<Map<String, dynamic>>()
          .map(RepoItem.fromJson)
          .toList()
        ..sort((a, b) {
          if (a.isDir && !b.isDir) return -1;
          if (!a.isDir && b.isDir) return 1;
          return a.name.compareTo(b.name);
        });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<({String content, String sha})> getFile(String path) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '$_repoBase/$path',
        queryParameters: {'ref': _config.branch},
      );
      final data = resp.data!;
      final encoded = (data['content'] as String).replaceAll('\n', '');
      final content = utf8.decode(base64.decode(encoded));
      return (content: content, sha: data['sha'] as String);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<String> createOrUpdateFile({
    required String path,
    required String content,
    String? sha,
    String? commitMessage,
  }) async {
    try {
      final message = commitMessage ??
          (sha == null ? 'Add $path' : 'Update $path');

      final body = <String, dynamic>{
        'message': message,
        'content': base64.encode(utf8.encode(content)),
        'branch': _config.branch,
      };
      if (sha != null) body['sha'] = sha;

      final resp = await _dio.put<Map<String, dynamic>>(
        '$_repoBase/$path',
        data: body,
      );
      return resp.data!['content']['sha'] as String;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteFile({
    required String path,
    required String sha,
    String? commitMessage,
  }) async {
    try {
      await _dio.delete<void>(
        '$_repoBase/$path',
        data: {
          'message': commitMessage ?? 'Delete $path',
          'sha': sha,
          'branch': _config.branch,
        },
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
