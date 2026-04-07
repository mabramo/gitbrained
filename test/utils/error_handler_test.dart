import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitbrained/utils/error_handler.dart';
import 'package:gitbrained/utils/exceptions.dart';

DioException _dioError(int statusCode) => DioException(
      requestOptions: RequestOptions(path: '/test'),
      response: Response(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: statusCode,
      ),
      type: DioExceptionType.badResponse,
    );

DioException _dioTimeout(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/test'),
      type: type,
    );

void main() {
  group('ErrorHandler.handle', () {
    test('passes through GitbrainedException unchanged', () {
      const original = AuthException('already typed');
      final result = ErrorHandler.handle(original);
      expect(result, same(original));
    });

    group('DioException — HTTP status codes', () {
      test('401 → AuthException', () {
        expect(ErrorHandler.handle(_dioError(401)), isA<AuthException>());
      });

      test('403 → AuthException', () {
        expect(ErrorHandler.handle(_dioError(403)), isA<AuthException>());
      });

      test('404 → NotFoundException', () {
        expect(ErrorHandler.handle(_dioError(404)), isA<NotFoundException>());
      });

      test('409 → ConflictException', () {
        expect(ErrorHandler.handle(_dioError(409)), isA<ConflictException>());
      });

      test('500 → ServerException', () {
        expect(ErrorHandler.handle(_dioError(500)), isA<ServerException>());
      });

      test('503 → ServerException', () {
        expect(ErrorHandler.handle(_dioError(503)), isA<ServerException>());
      });

      test('other status → GitbrainedException', () {
        final result = ErrorHandler.handle(_dioError(422));
        expect(result, isA<GitbrainedException>());
        expect(result, isNot(isA<ServerException>()));
        expect(result, isNot(isA<AuthException>()));
      });
    });

    group('DioException — timeout / connection', () {
      test('connectionTimeout → NetworkException', () {
        expect(
          ErrorHandler.handle(_dioTimeout(DioExceptionType.connectionTimeout)),
          isA<NetworkException>(),
        );
      });

      test('sendTimeout → NetworkException', () {
        expect(
          ErrorHandler.handle(_dioTimeout(DioExceptionType.sendTimeout)),
          isA<NetworkException>(),
        );
      });

      test('receiveTimeout → NetworkException', () {
        expect(
          ErrorHandler.handle(_dioTimeout(DioExceptionType.receiveTimeout)),
          isA<NetworkException>(),
        );
      });

      test('connectionError → NetworkException', () {
        expect(
          ErrorHandler.handle(_dioTimeout(DioExceptionType.connectionError)),
          isA<NetworkException>(),
        );
      });
    });

    test('IOException → StorageException', () {
      expect(
        ErrorHandler.handle(const FileSystemException('disk full')),
        isA<StorageException>(),
      );
    });

    test('unknown error → GitbrainedException', () {
      expect(
        ErrorHandler.handle(Exception('something random')),
        isA<GitbrainedException>(),
      );
    });
  });
}
