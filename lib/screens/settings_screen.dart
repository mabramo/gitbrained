import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/interfaces.dart';
import '../utils/snackbar_helper.dart';
import 'browser_screen.dart';

const _donationUrl = 'https://ko-fi.com/mabramo';

class SettingsScreen extends StatefulWidget {
  final bool isFirstLaunch;
  const SettingsScreen({super.key, this.isFirstLaunch = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _initialized = false;
  late IConfigService _config;
  late IGitService _git;
  late ISyncService _sync;

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _apiBaseUrl;
  late TextEditingController _ownerRepo;
  late TextEditingController _branch;
  late TextEditingController _pat;
  late TextEditingController _subdir;
  late int _syncInterval;

  bool _patObscured = true;
  bool _saving = false;

  static const _intervals = [5, 10, 15, 30];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _config = context.read<IConfigService>();
      _git = context.read<IGitService>();
      _sync = context.read<ISyncService>();

      _apiBaseUrl = TextEditingController(text: _config.apiBaseUrl);
      _ownerRepo = TextEditingController(text: _config.ownerRepo);
      _branch = TextEditingController(text: _config.branch);
      _pat = TextEditingController();
      _subdir = TextEditingController(text: _config.subdir);
      _syncInterval = _config.syncIntervalMinutes;

      _config.getPat().then((pat) {
        if (pat != null && mounted) _pat.text = pat;
      });
    }
  }

  @override
  void dispose() {
    _apiBaseUrl.dispose();
    _ownerRepo.dispose();
    _branch.dispose();
    _pat.dispose();
    _subdir.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await _config.setApiBaseUrl(_apiBaseUrl.text.trim());
      await _config.setOwnerRepo(_ownerRepo.text.trim());
      await _config.setBranch(_branch.text.trim());
      await _config.setSubdir(_subdir.text.trim());
      await _config.setSyncIntervalMinutes(_syncInterval);
      if (_pat.text.isNotEmpty) await _config.setPat(_pat.text);

      await _git.refreshAuth();
      _sync.restartTimer();

      setState(() => _saving = false);

      if (!mounted) return;
      if (widget.isFirstLaunch) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BrowserScreen(path: '')),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: !widget.isFirstLaunch,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.isFirstLaunch) ...[
              Text(
                'Gitbrained',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Connect your git repository to get started.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
            ],
            _sectionLabel('Repository', theme),
            const SizedBox(height: 8),
            _field(
              controller: _ownerRepo,
              label: 'Owner / Repo',
              hint: 'username/notes',
              validator: (v) =>
                  (v == null || !v.contains('/')) ? 'Enter as owner/repo' : null,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _branch,
              label: 'Branch',
              hint: 'main',
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _subdir,
              label: 'New notes subdirectory (optional)',
              hint: 'mobile',
            ),
            const SizedBox(height: 24),
            _sectionLabel('API', theme),
            const SizedBox(height: 8),
            _field(
              controller: _apiBaseUrl,
              label: 'API base URL',
              hint: 'https://api.github.com',
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            _sectionLabel('Auth', theme),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pat,
              obscureText: _patObscured,
              decoration: InputDecoration(
                labelText: 'Personal Access Token',
                suffixIcon: IconButton(
                  icon: Icon(
                    _patObscured ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _patObscured = !_patObscured),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel('Sync', theme),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _intervals.contains(_syncInterval) ? _syncInterval : 10,
              decoration: const InputDecoration(labelText: 'Sync interval'),
              items: _intervals
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text('Every $m minutes'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _syncInterval = v ?? 10),
            ),
            const SizedBox(height: 32),
            FilledButton(
              key: const Key('save_button'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
            const SizedBox(height: 12),
            if (!widget.isFirstLaunch) ...[
              const Divider(height: 40),
              OutlinedButton.icon(
                key: const Key('donate_button'),
                icon: const Icon(Icons.favorite_outline, size: 18),
                label: const Text('Support development'),
                onPressed: () async {
                  final uri = Uri.parse(_donationUrl);
                  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                    if (context.mounted) {
                      showErrorSnackBar(context, Exception('Could not open donation link.'));
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, ThemeData theme) {
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: validator,
    );
  }
}
