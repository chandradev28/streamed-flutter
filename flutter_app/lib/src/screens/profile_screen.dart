import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/torbox_api_service.dart';
import '../theme/app_colors.dart';
import 'addons_screen.dart';
import 'indexer_status_screen.dart';
import 'magnet_screen.dart';
import 'video_player_screen.dart';

class ProfileScreen extends StatefulWidget {
  ProfileScreen({
    super.key,
    TorBoxApiService? torBoxApiService,
    AppSettingsRepository? settingsRepository,
  })  : torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        settingsRepository = settingsRepository ?? AppSettingsRepository();

  final TorBoxApiService torBoxApiService;
  final AppSettingsRepository settingsRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  AppSettings _settings = const AppSettings();
  TorBoxUser? _user;
  List<TorBoxTorrent> _torrents = const <TorBoxTorrent>[];
  Set<int> _expanded = <int>{};
  bool _loading = true;
  bool _saving = false;
  String? _torBoxStatus;
  bool _keyConfigured = false;

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
    setState(() {
      _loading = true;
      _torBoxStatus = null;
    });

    final AppSettings settings = await widget.settingsRepository.loadSettings();
    _apiKeyController.text = settings.torBoxApiKey ?? '';
    final bool hasKey = settings.torBoxApiKey != null &&
        settings.torBoxApiKey!.trim().isNotEmpty;

    if (!hasKey) {
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _user = null;
        _torrents = const <TorBoxTorrent>[];
        _keyConfigured = false;
        _loading = false;
      });
      return;
    }

    try {
      final TorBoxAccountSnapshot snapshot =
          await widget.torBoxApiService.loadAccountSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _user = snapshot.user;
        _torrents = snapshot.torrents;
        _keyConfigured = true;
        _loading = false;
      });
    } on TorBoxApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _user = null;
        _torrents = const <TorBoxTorrent>[];
        _keyConfigured = true;
        _torBoxStatus = error.detail;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _user = null;
        _torrents = const <TorBoxTorrent>[];
        _keyConfigured = true;
        _torBoxStatus = 'Could not load your TorBox account right now.';
        _loading = false;
      });
    }
  }

  Future<void> _saveApiKey() async {
    final String apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
      _torBoxStatus = null;
    });

    if (!mounted) {
      return;
    }
    try {
      final TorBoxAccountSnapshot snapshot =
          await widget.torBoxApiService.connectAndLoad(apiKey);
      if (!mounted) {
        return;
      }
      final AppSettings settings =
          await widget.settingsRepository.loadSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _user = snapshot.user;
        _torrents = snapshot.torrents;
        _keyConfigured = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TorBox API key saved.')),
      );
    } on TorBoxApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _keyConfigured = false;
        _torBoxStatus = error.detail;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.detail)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final String message = 'Could not verify TorBox API key: $error';
      setState(() {
        _saving = false;
        _keyConfigured = false;
        _torBoxStatus = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _removeApiKey() async {
    await widget.settingsRepository.clearTorBoxApiKey();
    await _load();
  }

  Future<void> _setDnsProvider(DnsProvider provider) async {
    await widget.settingsRepository.saveDnsProvider(provider);
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = _settings.copyWith(dnsProvider: provider);
    });
  }

  Future<void> _deleteTorrent(TorBoxTorrent torrent) async {
    await widget.torBoxApiService.deleteTorrent(torrent.id);
    await _load();
  }

  void _openPlayer(TorBoxTorrent torrent, {TorBoxTorrentFile? file}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => VideoPlayerScreen(
          title: file?.displayName ?? torrent.name,
          torrentId: torrent.id,
          torrentHash: torrent.hash,
          initialFiles: torrent.files,
          initialFileId: file?.id,
          provider: 'torbox',
        ),
      ),
    );
  }

  void _toggleExpanded(int torrentId) {
    setState(() {
      if (_expanded.contains(torrentId)) {
        _expanded = _expanded.where((int id) => id != torrentId).toSet();
      } else {
        _expanded = <int>{..._expanded, torrentId};
      }
    });
  }

  void _openAddons() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AddonsScreen(),
      ),
    );
  }

  void _openIndexers() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const IndexerStatusScreen(),
      ),
    );
  }

  void _openMagnet() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MagnetScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'TorBox integration',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect the TorBox account used by search, library, magnet import, and the player tools.',
                      style:
                          TextStyle(color: AppColors.textMuted, height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      style: const TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: 'TorBox API key',
                        hintStyle: const TextStyle(color: AppColors.textSubtle),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
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
                          onPressed: _saving ? null : _saveApiKey,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.text,
                            foregroundColor: AppColors.background,
                          ),
                          child: Text(_saving ? 'Saving...' : 'Save key'),
                        ),
                        FilledButton.tonal(
                          onPressed: _settings.torBoxApiKey == null
                              ? null
                              : _removeApiKey,
                          child: const Text('Remove'),
                        ),
                        FilledButton.tonal(
                          onPressed: _openMagnet,
                          child: const Text('Open Magnet'),
                        ),
                        FilledButton.tonal(
                          onPressed: _loading ? null : _load,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                    if (_torBoxStatus != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _TorBoxStatusBanner(
                        message: _torBoxStatus!,
                        error: _user == null,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _QuickLinkCard(
                      title: 'Addons',
                      icon: Icons.extension_outlined,
                      onTap: _openAddons,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickLinkCard(
                      title: 'Sources',
                      icon: Icons.travel_explore_outlined,
                      onTap: _openIndexers,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'DNS / ISP bypass',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: DnsProvider.values.map((DnsProvider provider) {
                        final bool selected = _settings.dnsProvider == provider;
                        return ChoiceChip(
                          selected: selected,
                          label: Text(provider.label),
                          onSelected: (_) => _setDnsProvider(provider),
                          selectedColor: Colors.white,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.background
                                : AppColors.text,
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_user != null)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Account',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AccountRow(label: 'Email', value: _user!.email),
                      _AccountRow(label: 'Plan', value: _user!.plan),
                      if (_user!.hasSlotInfo)
                        _AccountRow(
                          label: 'Slots',
                          value: '${_user!.usedSlots}/${_user!.totalSlots}',
                        ),
                      if ((_user!.premiumExpiresAt ?? '').isNotEmpty)
                        _AccountRow(
                          label: 'Renews',
                          value: _user!.premiumExpiresAt!,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                'TorBox library (${_torrents.length})',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.text),
                  ),
                )
              else if (_torrents.isEmpty)
                _EmptyLibraryState(
                  keyConfigured: _keyConfigured,
                  statusMessage: _torBoxStatus,
                )
              else
                ..._torrents.map(
                  (TorBoxTorrent torrent) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  torrent.name,
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: torrent.files.isEmpty
                                    ? null
                                    : () => _openPlayer(torrent),
                                icon: const Icon(Icons.play_arrow_rounded),
                              ),
                              IconButton(
                                onPressed: () => _deleteTorrent(torrent),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFFCA5A5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _LibraryChip(label: _formatBytes(torrent.size)),
                              _LibraryChip(
                                  label: '${torrent.progress.round()}%'),
                              _LibraryChip(
                                label: torrent.downloadState.isEmpty
                                    ? 'Queued'
                                    : torrent.downloadState,
                              ),
                              if (torrent.files.length > 1)
                                _LibraryChip(
                                    label: '${torrent.files.length} files'),
                            ],
                          ),
                          if (torrent.files.length > 1) ...<Widget>[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => _toggleExpanded(torrent.id),
                              icon: Icon(
                                _expanded.contains(torrent.id)
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              label: Text(
                                _expanded.contains(torrent.id)
                                    ? 'Hide files'
                                    : 'Show files',
                              ),
                            ),
                            if (_expanded.contains(torrent.id))
                              ...torrent.files.map(
                                (TorBoxTorrentFile file) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    file.displayName,
                                    style:
                                        const TextStyle(color: AppColors.text),
                                  ),
                                  subtitle: Text(
                                    _formatBytes(file.size),
                                    style: const TextStyle(
                                        color: AppColors.textMuted),
                                  ),
                                  trailing: IconButton(
                                    onPressed: () =>
                                        _openPlayer(torrent, file: file),
                                    icon: const Icon(Icons.play_circle_outline),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    const List<String> sizes = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int index = 0;
    while (value >= 1024 && index < sizes.length - 1) {
      value /= 1024;
      index += 1;
    }

    return '${value.toStringAsFixed(value >= 10 || index == 0 ? 0 : 1)} ${sizes[index]}';
  }
}

class _TorBoxStatusBanner extends StatelessWidget {
  const _TorBoxStatusBanner({
    required this.message,
    required this.error,
  });

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        error ? const Color(0xFFFCA5A5) : const Color(0xFFBBF7D0);
    final Color background =
        error ? const Color(0x33EF4444) : const Color(0x3310B981);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: foreground,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  const _QuickLinkCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: AppColors.text, size: 24),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryChip extends StatelessWidget {
  const _LibraryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState({
    required this.keyConfigured,
    this.statusMessage,
  });

  final bool keyConfigured;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String body;
    if (!keyConfigured) {
      title = 'Connect TorBox to load your library.';
      body =
          'Paste your TorBox API key above, save it, and your account torrents will appear here.';
    } else if ((statusMessage ?? '').isNotEmpty) {
      title = 'TorBox library could not be loaded.';
      body = statusMessage!;
    } else {
      title = 'No TorBox torrents yet.';
      body =
          'Save your API key and add a magnet or start a Torboxers search to populate the library.';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_queue_outlined,
              color: AppColors.textMuted, size: 36),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
