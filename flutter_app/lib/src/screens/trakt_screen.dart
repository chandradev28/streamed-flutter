import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/trakt_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';

class TraktScreen extends StatefulWidget {
  TraktScreen({
    super.key,
    AppSettingsRepository? settingsRepository,
    TraktApiService? traktApiService,
  })  : settingsRepository = settingsRepository ?? AppSettingsRepository(),
        traktApiService = traktApiService ?? TraktApiService();

  final AppSettingsRepository settingsRepository;
  final TraktApiService traktApiService;

  @override
  State<TraktScreen> createState() => _TraktScreenState();
}

class _TraktScreenState extends State<TraktScreen> {
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _clientSecretController = TextEditingController();

  AppSettings _settings = const AppSettings();
  TraktDeviceCode? _deviceCode;
  Timer? _pollTimer;
  bool _loading = true;
  bool _busy = false;
  String? _status;

  Color get _accent => LayoutOptions.accentFor(_settings);
  bool get _connected => (_settings.traktAccessToken ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    _clientIdController.text = settings.traktClientId ?? '';
    _clientSecretController.text = settings.traktClientSecret ?? '';
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _saveCredentials() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await widget.traktApiService.saveCredentials(
        clientId: _clientIdController.text,
        clientSecret: _clientSecretController.text,
      );
      await _load();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Trakt app credentials saved.';
        _busy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _status = error.toString();
      });
    }
  }

  Future<void> _startLogin() async {
    await _saveCredentials();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Requesting Trakt login code...';
    });
    try {
      final TraktDeviceCode code =
          await widget.traktApiService.createDeviceCode();
      if (!mounted) {
        return;
      }
      setState(() {
        _deviceCode = code;
        _busy = false;
        _status = 'Complete Trakt sign in in your browser.';
      });
      unawaited(_openLogin());
      _startPolling(code);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _status = error.toString();
      });
    }
  }

  void _startPolling(TraktDeviceCode code) {
    _pollTimer?.cancel();
    final int interval = code.interval <= 0 ? 5 : code.interval;
    final DateTime expiresAt =
        DateTime.now().add(Duration(seconds: code.expiresIn));
    _pollTimer = Timer.periodic(Duration(seconds: interval), (Timer timer) {
      if (DateTime.now().isAfter(expiresAt)) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _status = 'Trakt login code expired. Start again.';
            _deviceCode = null;
          });
        }
        return;
      }
      unawaited(_pollToken(code));
    });
  }

  Future<void> _pollToken(TraktDeviceCode code) async {
    try {
      final TraktUser user =
          await widget.traktApiService.exchangeDeviceCode(code.deviceCode);
      _pollTimer?.cancel();
      await _load();
      if (!mounted) {
        return;
      }
      setState(() {
        _deviceCode = null;
        _status = 'Connected to Trakt as ${user.username}.';
      });
    } on TraktApiException catch (error) {
      if (error.statusCode == 400 ||
          error.detail.contains('pending') ||
          error.detail.contains('authorization')) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _status = error.detail;
      });
    }
  }

  Future<void> _openLogin() async {
    final TraktDeviceCode? code = _deviceCode;
    if (code == null) {
      return;
    }
    await launchUrl(
      Uri.parse(code.verificationUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _copyCode() async {
    final String? code = _deviceCode?.userCode;
    if (code == null || code.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trakt code copied.')),
    );
  }

  Future<void> _disconnect() async {
    _pollTimer?.cancel();
    await widget.traktApiService.disconnect();
    await _load();
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceCode = null;
      _status = 'Trakt disconnected.';
    });
  }

  Future<void> _saveToggle(AppSettings settings) async {
    setState(() {
      _settings = settings;
    });
    await widget.settingsRepository.saveSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LayoutOptions.backgroundFor(_settings),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _accent))
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 130),
                children: <Widget>[
                  _Header(accent: _accent),
                  const SizedBox(height: 24),
                  _HeroCard(accent: _accent, connected: _connected),
                  const SizedBox(height: 22),
                  const _SectionLabel('AUTHENTICATION'),
                  _SettingsCard(
                    children: <Widget>[
                      if (!_connected) ...<Widget>[
                        const Text(
                          'Create a Trakt API app, then paste its client ID and client secret here. Device login will open in your browser.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CredentialField(
                          label: 'Client ID',
                          controller: _clientIdController,
                        ),
                        const SizedBox(height: 12),
                        _CredentialField(
                          label: 'Client Secret',
                          controller: _clientSecretController,
                          obscureText: true,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            FilledButton(
                              onPressed: _busy ? null : _startLogin,
                              style: FilledButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: AppColors.background,
                              ),
                              child: Text(
                                _deviceCode == null
                                    ? 'Open Trakt Login'
                                    : 'Open Browser',
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: _busy ? null : _saveCredentials,
                              child: const Text('Save credentials'),
                            ),
                          ],
                        ),
                        if (_deviceCode != null) ...<Widget>[
                          const SizedBox(height: 18),
                          _CodePanel(
                            code: _deviceCode!,
                            accent: _accent,
                            onCopy: _copyCode,
                            onOpen: _openLogin,
                          ),
                        ],
                      ] else ...<Widget>[
                        _ConnectedPanel(
                          username: _settings.traktUsername ?? 'Trakt user',
                          lastSyncAt: _settings.traktLastSyncAt,
                          accent: _accent,
                          onDisconnect: _disconnect,
                        ),
                      ],
                      if ((_status ?? '').isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(
                          _status!,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('SYNC'),
                  _SettingsCard(
                    children: <Widget>[
                      _ToggleRow(
                        title: 'Scrobble playback',
                        subtitle:
                            'Send start, pause, and watched progress from the player.',
                        value: _settings.traktScrobbleEnabled,
                        accent: _accent,
                        onChanged: (bool value) => _saveToggle(
                          _settings.copyWith(traktScrobbleEnabled: value),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Sync progress',
                        subtitle:
                            'Use Trakt playback progress with Continue Watching.',
                        value: _settings.traktSyncProgressEnabled,
                        accent: _accent,
                        onChanged: (bool value) => _saveToggle(
                          _settings.copyWith(traktSyncProgressEnabled: value),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Sync watchlist',
                        subtitle:
                            'Show Trakt watchlist shelves on Home when connected.',
                        value: _settings.traktSyncWatchlistEnabled,
                        accent: _accent,
                        onChanged: (bool value) => _saveToggle(
                          _settings.copyWith(traktSyncWatchlistEnabled: value),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Sync watched history',
                        subtitle:
                            'Mark completed movies and episodes as watched on Trakt.',
                        value: _settings.traktSyncHistoryEnabled,
                        accent: _accent,
                        onChanged: (bool value) => _saveToggle(
                          _settings.copyWith(traktSyncHistoryEnabled: value),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Personal lists',
                        subtitle:
                            'Prepare custom Trakt lists for future Library shelves.',
                        value: _settings.traktSyncListsEnabled,
                        accent: _accent,
                        onChanged: (bool value) => _saveToggle(
                          _settings.copyWith(traktSyncListsEnabled: value),
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

class _Header extends StatelessWidget {
  const _Header({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded, color: accent),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Trakt',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.accent,
    required this.connected,
  });

  final Color accent;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFE11D8F), Color(0xFF7C2D92)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              connected ? Icons.check_rounded : Icons.checklist_rtl_rounded,
              color: AppColors.text,
              size: 38,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Sync your watchlist, watch progress, continue watching, scrobbles, and personal lists with Trakt.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
                height: 1.34,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodePanel extends StatelessWidget {
  const _CodePanel({
    required this.code,
    required this.accent,
    required this.onCopy,
    required this.onOpen,
  });

  final TraktDeviceCode code;
  final Color accent;
  final VoidCallback onCopy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Enter this code on Trakt',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            code.userCode,
            style: TextStyle(
              color: accent,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            code.verificationUrl,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.tonal(
                onPressed: onCopy,
                child: const Text('Copy code'),
              ),
              FilledButton.tonal(
                onPressed: onOpen,
                child: const Text('Open login'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectedPanel extends StatelessWidget {
  const _ConnectedPanel({
    required this.username,
    required this.lastSyncAt,
    required this.accent,
    required this.onDisconnect,
  });

  final String username;
  final int? lastSyncAt;
  final Color accent;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.sync_rounded, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                username,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                lastSyncAt == null
                    ? 'Connected'
                    : 'Last synced ${DateTime.fromMillisecondsSinceEpoch(lastSyncAt!).toLocal()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onDisconnect,
          child: const Text('Disconnect'),
        ),
      ],
    );
  }
}

class _CredentialField extends StatelessWidget {
  const _CredentialField({
    required this.label,
    required this.controller,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
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
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.value,
    required this.accent,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
