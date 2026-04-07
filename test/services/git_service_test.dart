import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gitbrained/services/config_service.dart';
import 'package:gitbrained/services/git_service.dart';
import 'package:gitbrained/utils/exceptions.dart';

class MockConfigService extends Mock implements ConfigService {}

void main() {
  late MockConfigService config;
  late Dio dio;
  late DioAdapter adapter;
  late GitService service;

  const owner = 'testowner';
  const repo = 'testrepo';
  const branch = 'main';
  const baseUrl = 'https://api.github.com';

  // Paths (without baseUrl) as the adapter matches against path, not full URL
  const repoBasePath = '/repos/$owner/$repo/contents';

  setUp(() {
    config = MockConfigService();
    when(() => config.apiBaseUrl).thenReturn(baseUrl);
    when(() => config.owner).thenReturn(owner);
    when(() => config.repo).thenReturn(repo);
    when(() => config.branch).thenReturn(branch);
    when(() => config.getPat()).thenAnswer((_) async => 'test-pat');

    dio = Dio(BaseOptions(baseUrl: baseUrl));
    adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher(matchMethod: true));

    service = GitService(config, dioFactory: (opts) => dio);
  });

  group('listDirectory', () {
    test('parses API response and sorts dirs before files', () async {
      adapter.onGet(
        repoBasePath,
        (server) => server.reply(200, [
          {'name': 'zfile.md', 'path': 'zfile.md', 'sha': 'sha1', 'type': 'file', 'download_url': null},
          {'name': 'adir', 'path': 'adir', 'sha': 'sha2', 'type': 'dir', 'download_url': null},
          {'name': 'afile.md', 'path': 'afile.md', 'sha': 'sha3', 'type': 'file', 'download_url': null},
        ]),
        queryParameters: {'ref': branch},
      );

      await service.init();
      final items = await service.listDirectory('');

      expect(items.length, 3);
      expect(items[0].isDir, isTrue);
      expect(items[0].name, 'adir');
      expect(items[1].name, 'afile.md');
      expect(items[2].name, 'zfile.md');
    });

    test('throws AuthException on 401', () async {
      adapter.onGet(
        repoBasePath,
        (server) => server.throws(
          401,
          DioException(
            requestOptions: RequestOptions(path: repoBasePath),
            response: Response(
              requestOptions: RequestOptions(path: repoBasePath),
              statusCode: 401,
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
        queryParameters: {'ref': branch},
      );

      await service.init();
      expect(
        () => service.listDirectory(''),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('getFile', () {
    test('decodes base64 content correctly', () async {
      const content = 'Hello, world!';
      final encoded = base64.encode(utf8.encode(content));
      const filePath = 'notes/hello.md';

      adapter.onGet(
        '$repoBasePath/$filePath',
        (server) => server.reply(200, {
          'content': '$encoded\n',
          'sha': 'fileshaabc',
        }),
        queryParameters: {'ref': branch},
      );

      await service.init();
      final result = await service.getFile(filePath);

      expect(result.content, content);
      expect(result.sha, 'fileshaabc');
    });

    test('throws NotFoundException on 404', () async {
      const filePath = 'missing.md';

      adapter.onGet(
        '$repoBasePath/$filePath',
        (server) => server.throws(
          404,
          DioException(
            requestOptions: RequestOptions(path: '$repoBasePath/$filePath'),
            response: Response(
              requestOptions: RequestOptions(path: '$repoBasePath/$filePath'),
              statusCode: 404,
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
        queryParameters: {'ref': branch},
      );

      await service.init();
      expect(
        () => service.getFile(filePath),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('createOrUpdateFile', () {
    test('sends correct body without sha (create) and returns new sha', () async {
      const path = 'notes/new.md';
      const content = '# New note';

      adapter.onPut(
        '$repoBasePath/$path',
        (server) => server.reply(200, {
          'content': {'sha': 'newsha123'},
        }),
      );

      await service.init();
      final sha = await service.createOrUpdateFile(path: path, content: content);
      expect(sha, 'newsha123');
    });

    test('sends correct body with sha (update) and returns updated sha', () async {
      const path = 'notes/existing.md';
      const content = 'updated content';

      adapter.onPut(
        '$repoBasePath/$path',
        (server) => server.reply(200, {
          'content': {'sha': 'updatedsha'},
        }),
      );

      await service.init();
      final sha = await service.createOrUpdateFile(
        path: path,
        content: content,
        sha: 'oldsha',
      );
      expect(sha, 'updatedsha');
    });

    test('throws ConflictException on 409', () async {
      const path = 'notes/conflict.md';

      adapter.onPut(
        '$repoBasePath/$path',
        (server) => server.throws(
          409,
          DioException(
            requestOptions: RequestOptions(path: '$repoBasePath/$path'),
            response: Response(
              requestOptions: RequestOptions(path: '$repoBasePath/$path'),
              statusCode: 409,
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      await service.init();
      expect(
        () => service.createOrUpdateFile(path: path, content: 'content'),
        throwsA(isA<ConflictException>()),
      );
    });
  });
}
