import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/stream_badge_service.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';

class StreamsScreen extends StatefulWidget {
  StreamsScreen({
    super.key,
    AppSettingsRepository? settingsRepository,
    StreamBadgeService? badgeService,
  })  : settingsRepository = settingsRepository ?? AppSettingsRepository(),
        badgeService = badgeService ?? const StreamBadgeService();

  final AppSettingsRepository settingsRepository;
  final StreamBadgeService badgeService;

  @override
  State<StreamsScreen> createState() => _StreamsScreenState();
}

class _StreamsScreenState extends State<StreamsScreen> {
  final TextEditingController _jsonController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  AppSettings _settings = const AppSettings();
  List<StreamBadge> _previewBadges = const <StreamBadge>[];
  bool _loading = true;
  bool _importing = false;
  String? _error;

  Color get _accent => LayoutOptions.accentFor(_settings);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    _jsonController.text = settings.streamBadgesJson;
    setState(() {
      _settings = settings;
      _previewBadges = _parsePreview(settings.streamBadgesJson);
      _loading = false;
    });
  }

  List<StreamBadge> _parsePreview(String raw) {
    try {
      _error = null;
      return widget.badgeService.parseBadges(raw);
    } catch (error) {
      _error = 'Could not parse Badger JSON: $error';
      return const <StreamBadge>[];
    }
  }

  Future<void> _save({
    bool? enabled,
    String? json,
  }) async {
    final AppSettings next = _settings.copyWith(
      streamBadgesEnabled: enabled,
      streamBadgesJson: json,
    );
    await widget.settingsRepository.saveSettings(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = next;
      _previewBadges = _parsePreview(next.streamBadgesJson);
    });
  }

  Future<void> _saveJson() async {
    final String raw = _jsonController.text.trim();
    try {
      final List<StreamBadge> badges = widget.badgeService.parseBadges(raw);
      await _save(json: raw, enabled: badges.isNotEmpty);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${badges.length} stream badges.')),
      );
    } catch (error) {
      setState(() {
        _error = 'Could not save badges: $error';
        _previewBadges = const <StreamBadge>[];
      });
    }
  }

  Future<void> _clear() async {
    _jsonController.clear();
    await _save(json: '', enabled: false);
  }

  Future<void> _openBadger() async {
    await launchUrl(
      Uri.parse('https://nintle.github.io/Badger/'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _importUrl() async {
    final Uri? uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null || !uri.hasScheme) {
      setState(() {
        _error = 'Paste a direct JSON URL first.';
      });
      return;
    }

    setState(() {
      _importing = true;
      _error = null;
    });

    try {
      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json,text/*');
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 16));
      final String raw = await response.transform(utf8.decoder).join();
      client.close(force: true);
      widget.badgeService.parseBadges(raw);
      _jsonController.text = raw;
      await _saveJson();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not import badge JSON: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
        });
      }
    }
  }

  void _refreshPreview() {
    setState(() {
      _previewBadges = _parsePreview(_jsonController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LayoutOptions.backgroundFor(_settings),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _accent))
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 120),
                children: <Widget>[
                  _StreamsTitle(accent: _accent),
                  const SizedBox(height: 24),
                  const _SectionLabel('BADGES'),
                  _SettingsCard(
                    children: <Widget>[
                      _ToggleRow(
                        title: 'Show stream badges',
                        subtitle:
                            'Match Badger regex filters against source titles and filenames.',
                        value: _settings.streamBadgesEnabled,
                        accent: _accent,
                        onChanged: (bool value) => _save(enabled: value),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _openBadger,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: AppColors.background,
                            ),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open Badger'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _refreshPreview,
                            icon: const Icon(Icons.visibility_rounded),
                            label: const Text('Preview'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('IMPORT'),
                  _SettingsCard(
                    children: <Widget>[
                      const Text(
                        'Paste a Badger export JSON below, or paste a direct raw JSON URL. The app supports full exports with a filters array, raw badge arrays, and single badge JSON.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _urlController,
                        style: const TextStyle(color: AppColors.text),
                        decoration: _inputDecoration(
                          hint: 'https://.../badges.json',
                          accent: _accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _importing ? null : _importUrl,
                          icon: _importing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_rounded),
                          label:
                              Text(_importing ? 'Importing...' : 'Import URL'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _jsonController,
                        onChanged: (_) => _refreshPreview(),
                        minLines: 8,
                        maxLines: 16,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        decoration: _inputDecoration(
                          hint: '{"filters":[...]}',
                          accent: _accent,
                        ),
                      ),
                      if ((_error ?? '').isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          FilledButton(
                            onPressed: _saveJson,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: AppColors.background,
                            ),
                            child: const Text('Save badges'),
                          ),
                          OutlinedButton(
                            onPressed: _clear,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('PREVIEW'),
                  _SettingsCard(
                    children: <Widget>[
                      Text(
                        _previewBadges.isEmpty
                            ? 'No badges parsed yet.'
                            : '${_previewBadges.length} badges ready.',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _BadgePreview(badges: _previewBadges.take(18).toList()),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _StreamsTitle extends StatelessWidget {
  const _StreamsTitle({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_rounded, color: accent),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Streams',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 40,
              height: 0.98,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            ),
          ),
        ),
      ],
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
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _BadgePreview extends StatelessWidget {
  const _BadgePreview({required this.badges});

  final List<StreamBadge> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const Text(
        'Paste Badger JSON to preview badges here.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }
    return Wrap(
      spacing: 9,
      runSpacing: 8,
      children: badges
          .map(
            (StreamBadge badge) => _PreviewBadge(badge: badge),
          )
          .toList(growable: false),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.badge});

  final StreamBadge badge;

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = badge.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 104, maxHeight: 30),
        child: Image.network(
          imageUrl,
          height: 24,
          fit: BoxFit.contain,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stack) {
            return _FallbackBadge(badge: badge);
          },
        ),
      );
    }
    return _FallbackBadge(badge: badge);
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge({required this.badge});

  final StreamBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _parseColor(badge.tagColor) ?? Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color:
              _parseColor(badge.borderColor) ?? Colors.white.withOpacity(0.1),
        ),
      ),
      child: Text(
        badge.name,
        style: TextStyle(
          color: _parseColor(badge.textColor) ?? AppColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String hint,
  required Color accent,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textSubtle),
    filled: true,
    fillColor: Colors.white.withOpacity(0.06),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accent),
    ),
  );
}

Color? _parseColor(String? raw) {
  final String value = (raw ?? '').trim();
  if (value.isEmpty ||
      value == '#00000000' ||
      value.toLowerCase() == 'transparent') {
    return null;
  }
  final String hex = value.replaceFirst('#', '');
  if (hex.length != 6 && hex.length != 8) {
    return null;
  }
  final int? parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
}
