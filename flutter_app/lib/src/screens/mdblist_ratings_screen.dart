import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/mdblist_api_service.dart';
import '../theme/app_colors.dart';

class MdbListRatingsScreen extends StatefulWidget {
  MdbListRatingsScreen({
    super.key,
    AppSettingsRepository? settingsRepository,
    MdbListApiService? mdbListApiService,
  })  : settingsRepository = settingsRepository ?? AppSettingsRepository(),
        mdbListApiService = mdbListApiService ?? MdbListApiService();

  final AppSettingsRepository settingsRepository;
  final MdbListApiService mdbListApiService;

  @override
  State<MdbListRatingsScreen> createState() => _MdbListRatingsScreenState();
}

class _MdbListRatingsScreenState extends State<MdbListRatingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  AppSettings _settings = const AppSettings();
  bool _saving = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _apiKeyController.text = settings.mdbListApiKey ?? '';
    });
  }

  Future<void> _save(AppSettings settings) async {
    await widget.settingsRepository.saveSettings(settings);
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
  }

  Future<void> _saveApiKey() async {
    final String key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      return;
    }
    setState(() {
      _saving = true;
      _status = null;
    });
    final bool valid = await widget.mdbListApiService.verifyApiKey(key);
    if (!mounted) {
      return;
    }
    if (!valid) {
      setState(() {
        _saving = false;
        _status = 'Could not verify this MDBList API key.';
      });
      return;
    }
    final AppSettings next = _settings.copyWith(mdbListApiKey: key);
    await widget.settingsRepository.saveSettings(next);
    setState(() {
      _settings = next;
      _saving = false;
      _status = 'MDBList API key saved.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'MDBList\nRatings',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 38,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('MDBLIST RATINGS'),
            _SettingsPanel(
              children: <Widget>[
                _SwitchRow(
                  title: 'Enable MDBList Ratings',
                  subtitle:
                      'Fetch ratings from external providers in metadata detail screens.',
                  value: _settings.mdbListRatingsEnabled,
                  onChanged: (bool value) =>
                      _save(_settings.copyWith(mdbListRatingsEnabled: value)),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Add your MDBList API key below before turning ratings on.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ),
            const _SectionLabel('API KEY'),
            _SettingsPanel(
              children: <Widget>[
                const _FieldTitle(
                  title: 'API Key',
                  subtitle: 'Required to fetch ratings from MDBList.',
                ),
                _SecretField(
                  controller: _apiKeyController,
                  hintText: 'API Key',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _saveApiKey,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
                if ((_status ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    _status!,
                    style: TextStyle(
                      color: _status!.contains('saved')
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFCA5A5),
                    ),
                  ),
                ],
              ],
            ),
            const _SectionLabel('EXTERNAL RATINGS PROVIDERS'),
            _SettingsPanel(
              children: <Widget>[
                _SwitchRow(
                  title: 'IMDb',
                  subtitle: 'IMDb rating and vote count.',
                  value: _settings.mdbListImdbEnabled,
                  onChanged: (bool value) =>
                      _save(_settings.copyWith(mdbListImdbEnabled: value)),
                ),
                _SwitchRow(
                  title: 'TMDB',
                  subtitle: 'TMDB rating from MDBList response.',
                  value: _settings.mdbListTmdbEnabled,
                  onChanged: (bool value) =>
                      _save(_settings.copyWith(mdbListTmdbEnabled: value)),
                ),
                _SwitchRow(
                  title: 'Rotten Tomatoes',
                  subtitle: 'Critic Tomatometer score when available.',
                  value: _settings.mdbListRottenTomatoesEnabled,
                  onChanged: (bool value) => _save(
                    _settings.copyWith(mdbListRottenTomatoesEnabled: value),
                  ),
                ),
                _SwitchRow(
                  title: 'Metacritic',
                  subtitle: 'Metascore when MDBList exposes it.',
                  value: _settings.mdbListMetacriticEnabled,
                  onChanged: (bool value) => _save(
                    _settings.copyWith(mdbListMetacriticEnabled: value),
                  ),
                ),
                _SwitchRow(
                  title: 'Trakt',
                  subtitle: 'Trakt community rating.',
                  value: _settings.mdbListTraktEnabled,
                  onChanged: (bool value) =>
                      _save(_settings.copyWith(mdbListTraktEnabled: value)),
                ),
                _SwitchRow(
                  title: 'Letterboxd',
                  subtitle: 'Letterboxd score normalized for display.',
                  value: _settings.mdbListLetterboxdEnabled,
                  onChanged: (bool value) => _save(
                    _settings.copyWith(mdbListLetterboxdEnabled: value),
                  ),
                ),
                _SwitchRow(
                  title: 'Audience Score',
                  subtitle: 'Audience or Popcornmeter style scores.',
                  value: _settings.mdbListAudienceScoreEnabled,
                  onChanged: (bool value) => _save(
                    _settings.copyWith(mdbListAudienceScoreEnabled: value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.25,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FieldTitle extends StatelessWidget {
  const _FieldTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SecretField extends StatefulWidget {
  const _SecretField({
    required this.controller,
    required this.hintText,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: AppColors.textSubtle),
        suffixIcon: IconButton(
          onPressed: () => setState(() {
            _visible = !_visible;
          }),
          icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
        ),
        filled: true,
        fillColor: Colors.black.withOpacity(0.14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
    );
  }
}
