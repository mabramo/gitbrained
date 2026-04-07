class GitbrainedException implements Exception {
  final String message;
  final String? detail;
  const GitbrainedException(this.message, {this.detail});
  @override
  String toString() => message;
}

class NetworkException extends GitbrainedException {
  const NetworkException(super.message, {super.detail});
}

class AuthException extends GitbrainedException {
  const AuthException(super.message, {super.detail});
}

class NotFoundException extends GitbrainedException {
  const NotFoundException(super.message, {super.detail});
}

class ConflictException extends GitbrainedException {
  const ConflictException(super.message, {super.detail});
}

class ServerException extends GitbrainedException {
  const ServerException(super.message, {super.detail});
}

class ConfigException extends GitbrainedException {
  const ConfigException(super.message, {super.detail});
}

class StorageException extends GitbrainedException {
  const StorageException(super.message, {super.detail});
}
