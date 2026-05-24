import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/real_debrid_api_service.dart';
import '../services/torbox_api_service.dart';
import '../theme/app_colors.dart';

class ConnectedServicesScreen extends StatefulWidget {
  ConnectedServicesScreen({
    super.key,
    AppSettingsRepository? settingsRepository,
    TorBoxApiService? torBoxApiService,
    RealDebridApiService? realDebridApiService,
  })  : settingsRepository = settingsRepository ?? AppSettingsRepository(),
        torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        realDebridApiService = realDebridApiService ?? RealDebridApiService();

  final AppSettingsRepository settingsRepository;
  final TorBoxApiService torBoxApiService;
  final RealDebridApiService realDebridApiService;

  @override
  State<ConnectedServicesScreen> createState() =>
      _ConnectedServicesScreenState();
}

class _ConnectedServicesScreenState extends State<ConnectedServicesScreen> {
  final TextEditingController _torBoxController = TextEditingController();
  final TextEditingController _realDebridController = TextEditingController();

  AppSettings _settings = const AppSettings();
  TorBoxUser? _torBoxUser;
  RealDebridUser? _realDebridUser;
  bool _loading = true;
  bool _saving = false;
  String? _torBoxStatus;
  String? _realDebridStatus;

  bool get _hasConnectedAccount =>
      (_settings.torBoxApiKey ?? '').trim().isNotEmpty ||
      (_settings.realDebridApiKey ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _torBoxController.dispose();
    _realDebridController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _torBoxStatus = null;
      _realDebridStatus = null;
    });

    final AppSettings settings = await widget.settingsRepository.loadSettings();
    _torBoxController.text = settings.torBoxApiKey ?? '';
    _realDebridController.text = settings.realDebridApiKey ?? '';

    TorBoxUser? torBoxUser;
    RealDebridUser? realDebridUser;
    String? torBoxStatus;
    String? realDebridStatus;

    if ((settings.torBoxApiKey ?? '').trim().isNotEmpty) {
      try {
        torBoxUser = await widget.torBoxApiService.getUserInfo();
      } on TorBoxApiException catch (error) {
        torBoxStatus = error.detail;
      } catch (_) {
        torBoxStatus = 'Could not load your TorBox account.';
      }
    }

    if ((settings.realDebridApiKey ?? '').trim().isNotEmpty) {
      try {
        realDebridUser = await widget.realDebridApiService.getUserInfo();
      } on RealDebridApiException catch (error) {
        realDebridStatus = error.detail;
      } catch (_) {
        realDebridStatus = 'Could not load your Real-Debrid account.';
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = settings;
      _torBoxUser = torBoxUser;
      _realDebridUser = realDebridUser;
      _torBoxStatus = torBoxStatus;
      _realDebridStatus = realDebridStatus;
      _loading = false;
    });
  }

  Future<void> _saveTorBoxKey() async {
    final String key = _torBoxController.text.trim();
    if (key.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
      _torBoxStatus = null;
    });

    try {
      final TorBoxUser user =
          await widget.torBoxApiService.getUserInfo(apiKeyOverride: key);
      await widget.settingsRepository.saveTorBoxApiKey(key);
      final AppSettings settings =
          await widget.settingsRepository.loadSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _torBoxUser = user;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TorBox account connected.')),
      );
    } on TorBoxApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _torBoxStatus = error.detail;
      });
    }
  }

  Future<void> _saveRealDebridKey() async {
    final String key = _realDebridController.text.trim();
    if (key.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
      _realDebridStatus = null;
    });

    try {
      final RealDebridUser user =
          await widget.realDebridApiService.connect(key);
      final AppSettings settings =
          await widget.settingsRepository.loadSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _realDebridUser = user;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Real-Debrid account connected.')),
      );
    } on RealDebridApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _realDebridStatus = error.detail;
      });
    }
  }

  Future<void> _removeTorBoxKey() async {
    await widget.settingsRepository.clearTorBoxApiKey();
    await _load();
  }

  Future<void> _removeRealDebridKey() async {
    await widget.settingsRepository.clearRealDebridApiKey();
    await _load();
  }

  Future<void> _setCloudLibraryEnabled(bool value) async {
    await widget.settingsRepository.saveCloudLibraryEnabled(value);
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
  }

  Future<void> _setResolvePlayableLinksEnabled(bool value) async {
    await widget.settingsRepository.saveResolvePlayableLinksEnabled(value);
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.text,
          backgroundColor: AppColors.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Connected\nServices',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 42,
                        height: 0.98,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: <Widget>[
                    const Text(
                      'These integrations are experimental and may be kept, changed, or removed later.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FeatureSwitchTile(
                      title: 'Cloud library',
                      subtitle:
                          'Browse and play files already in your connected accounts.',
                      value: _settings.cloudLibraryEnabled,
                      enabled: _hasConnectedAccount,
                      onChanged: _setCloudLibraryEnabled,
                    ),
                    const SizedBox(height: 16),
                    _FeatureSwitchTile(
                      title: 'Resolve playable links',
                      subtitle:
                          'Ask a connected service for playable links when a result needs it.',
                      value: _settings.resolvePlayableLinksEnabled,
                      enabled: _hasConnectedAccount,
                      onChanged: _setResolvePlayableLinksEnabled,
                    ),
                    if (!_hasConnectedAccount) ...<Widget>[
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Connect an account first.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _SectionLabel('ACCOUNTS'),
              _AccountCard(
                children: <Widget>[
                  _ServiceKeyPanel(
                    title: 'TorBox',
                    subtitle: _torBoxUser == null
                        ? 'Paste your TorBox API key.'
                        : '${_torBoxUser!.email} - ${_torBoxUser!.plan}',
                    status: _torBoxStatus,
                    controller: _torBoxController,
                    hintText: 'TorBox API key',
                    connected: (_settings.torBoxApiKey ?? '').isNotEmpty,
                    loading: _loading || _saving,
                    onSave: _saveTorBoxKey,
                    onRemove: _removeTorBoxKey,
                  ),
                  const Divider(height: 1, color: Color(0x14FFFFFF)),
                  _ServiceKeyPanel(
                    title: 'Real-Debrid',
                    subtitle: _realDebridUser == null
                        ? 'Paste your Real-Debrid API token.'
                        : '${_realDebridUser!.username} - ${_realDebridUser!.type}',
                    status: _realDebridStatus,
                    controller: _realDebridController,
                    hintText: 'Real-Debrid API token',
                    connected: (_settings.realDebridApiKey ?? '').isNotEmpty,
                    loading: _loading || _saving,
                    onSave: _saveRealDebridKey,
                    onRemove: _removeRealDebridKey,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cloud library adds TorBox and Real-Debrid items to the Library tab.',
                      ),
                    ),
                  );
                },
                child: const Text('Learn more'),
              ),
            ],
          ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}

class _FeatureSwitchTile extends StatelessWidget {
  const _FeatureSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: enabled ? AppColors.text : AppColors.textMuted,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value && enabled,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }
}

class _ServiceKeyPanel extends StatelessWidget {
  const _ServiceKeyPanel({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.hintText,
    required this.connected,
    required this.loading,
    required this.onSave,
    required this.onRemove,
    this.status,
  });

  final String title;
  final String subtitle;
  final TextEditingController controller;
  final String hintText;
  final bool connected;
  final bool loading;
  final Future<void> Function() onSave;
  final Future<void> Function() onRemove;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                connected ? 'Set' : 'Not set',
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: AppColors.textSubtle),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton(
                onPressed: loading ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.text,
                  foregroundColor: AppColors.background,
                ),
                child: Text(loading ? 'Working...' : 'Save'),
              ),
              FilledButton.tonal(
                onPressed: connected && !loading ? onRemove : null,
                child: const Text('Remove'),
              ),
            ],
          ),
          if ((status ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              status!,
              style: const TextStyle(
                color: Color(0xFFFCA5A5),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
