import 'package:mocktail/mocktail.dart';
import 'package:gitbrained/services/interfaces.dart';

class MockGitService extends Mock implements IGitService {}

class MockLocalStorageService extends Mock implements ILocalStorageService {}

class MockConfigService extends Mock implements IConfigService {}

class MockSyncService extends Mock implements ISyncService {}
