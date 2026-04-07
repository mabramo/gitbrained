import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'interfaces.dart';

class ConfigService implements IConfigService {
  static const _keyApiBaseUrl = 'api_base_url';
  static const _keyOwnerRepo = 'owner_repo';
  static const _keyBranch = 'branch';
  static const _keySubdir = 'subdir';
  static const _keySyncInterval = 'sync_interval_minutes';
  static const _keyPat = 'pat';

  static const defaultApiBaseUrl = 'https://api.github.com';
  static const defaultBranch = 'main';
  static const defaultSyncInterval = 10;

  final FlutterSecureStorage _secure;
  late SharedPreferences _prefs;

  ConfigService() : _secure = const FlutterSecureStorage();

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<String?> getPat() => _secure.read(key: _keyPat);
  @override
  Future<void> setPat(String value) => _secure.write(key: _keyPat, value: value);

  @override
  String get apiBaseUrl => _prefs.getString(_keyApiBaseUrl) ?? defaultApiBaseUrl;
  @override
  String get ownerRepo => _prefs.getString(_keyOwnerRepo) ?? '';
  @override
  String get branch => _prefs.getString(_keyBranch) ?? defaultBranch;
  @override
  String get subdir => _prefs.getString(_keySubdir) ?? '';
  @override
  int get syncIntervalMinutes => _prefs.getInt(_keySyncInterval) ?? defaultSyncInterval;

  @override
  Future<void> setApiBaseUrl(String v) => _prefs.setString(_keyApiBaseUrl, v);
  @override
  Future<void> setOwnerRepo(String v) => _prefs.setString(_keyOwnerRepo, v);
  @override
  Future<void> setBranch(String v) => _prefs.setString(_keyBranch, v);
  @override
  Future<void> setSubdir(String v) => _prefs.setString(_keySubdir, v);
  @override
  Future<void> setSyncIntervalMinutes(int v) => _prefs.setInt(_keySyncInterval, v);

  @override
  bool get isConfigured => ownerRepo.isNotEmpty;

  @override
  String get owner => ownerRepo.contains('/') ? ownerRepo.split('/').first : '';
  @override
  String get repo => ownerRepo.contains('/') ? ownerRepo.split('/').last : '';
}
