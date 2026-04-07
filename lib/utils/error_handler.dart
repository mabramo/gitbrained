import 'dart:io';
import 'package:dio/dio.dart';
import 'exceptions.dart';

class ErrorHandler {
  static GitbrainedException handle(Object error) {
    if (error is GitbrainedException) return error;

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return NetworkException(
            'Request timed out. Check your connection.',
            detail: error.message,
          );
        case DioExceptionType.connectionError:
          return NetworkException(
            'No connection. Check your network.',
            detail: error.message,
          );
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode;
          if (status == 401 || status == 403) {
            return AuthException(
              'Authentication failed. Check your token.',
              detail: error.message,
            );
          }
          if (status == 404) {
            return NotFoundException(
              'Not found.',
              detail: error.message,
            );
          }
          if (status == 409) {
            return ConflictException(
              'Conflict: the file has been modified remotely.',
              detail: error.message,
            );
          }
          if (status != null && status >= 500) {
            return ServerException(
              'Server error ($status). Try again later.',
              detail: error.message,
            );
          }
          return GitbrainedException(
            'Unexpected error ($status).',
            detail: error.message,
          );
        default:
          return GitbrainedException(
            'Something went wrong. Try again.',
            detail: error.message,
          );
      }
    }

    if (error is IOException) {
      return StorageException(
        'Storage error. Check device storage.',
        detail: error.toString(),
      );
    }

    return GitbrainedException(
      'Something went wrong. Try again.',
      detail: error.toString(),
    );
  }
}
