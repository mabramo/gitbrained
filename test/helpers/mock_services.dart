import 'package:mocktail/mocktail.dart';
import 'package:gitbrained/models/note.dart';
import 'package:gitbrained/models/repo_item.dart';
import 'package:gitbrained/services/interfaces.dart';

class MockGitService extends Mock implements IGitService {}

class MockLocalStorageService extends Mock implements ILocalStorageService {}

class MockConfigService extends Mock implements IConfigService {}

class MockSyncService extends Mock implements ISyncService {}

/// Register fallback values for non-primitive types used in mocktail matchers.
/// Call once in [setUpAll].
void registerFallbacks() {
  registerFallbackValue(
    const RepoItem(name: '', path: '', sha: '', type: 'file'),
  );
  registerFallbackValue(const SyncState());
  registerFallbackValue(<RepoItem>[]);
  registerFallbackValue(<String>{});
  registerFallbackValue(<String, String>{});
}
