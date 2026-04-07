import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/config_service.dart';
import 'services/git_service.dart';
import 'services/interfaces.dart';
import 'services/local_storage_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = ConfigService();
  await config.init();
  final local = LocalStorageService();
  await local.init();
  final git = GitService(config);
  if (config.isConfigured) await git.init();
  final sync = SyncService(config, git, local);
  if (config.isConfigured) sync.startTimer();

  runApp(
    MultiProvider(
      providers: [
        Provider<IConfigService>.value(value: config),
        Provider<ILocalStorageService>.value(value: local),
        Provider<IGitService>.value(value: git),
        Provider<ISyncService>.value(value: sync),
      ],
      child: GitbrainedApp(isConfigured: config.isConfigured),
    ),
  );
}
