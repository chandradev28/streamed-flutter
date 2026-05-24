import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/real_debrid_api_service.dart';
import '../services/torbox_api_service.dart';
import '../theme/app_colors.dart';
import 'addons_screen.dart';
import 'indexer_status_screen.dart';
import 'magnet_screen.dart';
import 'torboxers_screen.dart';
import 'video_player_screen.dart';

class ProfileScreen extends StatefulWidget {
  ProfileScreen({
    super.key,
    TorBoxApiService? torBoxApiService,
    RealDebridApiService? realDebridApiService,
    AppSettingsRepository? settingsRepository,
  })  : torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        realDebridApiService = realDebridApiService ?? RealDebridApiService(),
        settingsRepository = settingsRepository ?? AppSettingsRepository();

  final TorBoxApiService torBoxApiService;
  final RealDebridApiService realDebridApiService;
  final AppSettingsRepository settingsRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _realDebridKeyController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  AppSettings _settings = const AppSettings();
  TorBoxUser? _user;
  RealDebridUser? _realDebridUser;
  List<TorBoxTorrent> _torrents = const <TorBoxTorrent>[];
  Set<int> _expanded = <int>{};
  bool _loading = true;
  bool _saving = false;
  String? _torBoxStatus;
  String? _realDebridStatus;
  bool _keyConfigured = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _realDebridKeyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _torBoxStatus = null;
    });

    final AppSettings settings = await widget.settingsRepository.loadSettings();
    _apiKeyController.text = settings.torBoxApiKey ?? '';
    _realDebridKeyController.text = settings.realDebridApiKey ?? '';
    final bool hasKey = settings.torBoxApiKey != null &&
        settings.torBoxApiKey!.trim().isNotEmpty;
    final bool hasRealDebridKey = settings.realDebridApiKey != null &&
        settings.realDebridApiKey!.trim().isNotEmpty;
    RealDebridUser? realDebridUser;
    String? realDebridStatus;
    if (hasRealDebridKey) {
      try {
        realDebridUser = await widget.realDebridApiService.getUserInfo();
      } on RealDebridApiException catch (error) {
        realDebridStatus = error.detail;
      } catch (_) {
        realDebridStatus = 'Could not load your Real-Debrid account.';
      }
    }

    if (!hasKey) {
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _user = null;
        _realDebridUser = realDebridUser;
        _torrents = const <TorBoxTorrent>[];
        _keyConfigured = false;
        _realDebridStatus = realDebridStatus;
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
        _realDebridUser = realDebridUser;
        _torrents = snapshot.torrents;
        _keyConfigured = true;
        _realDebridStatus = realDebridStatus;
        _loading = false;
      });
    } on TorBoxApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _user = null;
        _realDebridUser = realDebridUser;
        _torrents = const <TorBoxTorrent>[];
        _keyConfigured = true;
        _torBoxStatus = error.detail;
        _realDebridStatus = realDebridStatus;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _user = null;
        _realDebridUser = realDebridUser;
        _torrents = const <TorBoxTorrent>[];
        _keyConfigured = true;
        _torBoxStatus = 'Could not load your TorBox account right now.';
        _realDebridStatus = realDebridStatus;
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

  Future<void> _saveRealDebridApiKey() async {
    final String apiKey = _realDebridKeyController.text.trim();
    if (apiKey.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
      _realDebridStatus = null;
    });

    try {
      final RealDebridUser user =
          await widget.realDebridApiService.connect(apiKey);
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
        const SnackBar(content: Text('Real-Debrid token saved.')),
      );
    } on RealDebridApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _realDebridStatus = error.detail;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.detail)),
      );
    }
  }

  Future<void> _removeRealDebridApiKey() async {
    await widget.settingsRepository.clearRealDebridApiKey();
    await _load();
  }

  Future<void> _setPreferredDebrid(String provider) async {
    await widget.settingsRepository.savePreferredDebridProvider(provider);
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
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

  void _openMagnet() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MagnetScreen(),
      ),
    );
  }

  void _openTorboxers() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TorboxersScreen(),
      ),
    );
  }

  void _openAddons() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AddonsScreen(),
      ),
    );
  }

  void _openIndexerStatus() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => IndexerStatusScreen(),
      ),
    );
  }

  bool _matchesSettingsSearch(String value) {
    final String query = _searchController.text.trim().toLowerCase();
    return query.isEmpty || value.toLowerCase().contains(query);
  }

  void _showPlaceholder(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title is not wired yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showAccount = _matchesSettingsSearch(
      'account profile trakt sync torbox real debrid plan library',
    );
    final bool showGeneral = _matchesSettingsSearch(
      'general layout content discovery addons sources indexer torboxers downloads integrations torbox real debrid',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Search settings...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  hintStyle: const TextStyle(color: AppColors.textSubtle),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              if (showAccount) ...<Widget>[
                const _SettingsSectionLabel('ACCOUNT'),
                _SettingsGroupCard(
                  children: <Widget>[
                    _SettingsActionTile(
                      icon: Icons.groups_rounded,
                      title: 'Switch Profile',
                      subtitle: 'Change to a different profile.',
                      onTap: () => _showPlaceholder('Switch Profile'),
                    ),
                    _SettingsActionTile(
                      icon: Icons.account_circle_rounded,
                      title: 'Account',
                      subtitle: _user == null
                          ? 'Account and sync status'
                          : '${_user!.email} · ${_user!.plan}',
                      onTap: _loading ? null : _load,
                    ),
                    _SettingsActionTile(
                      icon: Icons.checklist_rtl_rounded,
                      title: 'Trakt',
                      subtitle: 'Open Trakt connection screen',
                      accent: const Color(0xFFCE3CCB),
                      onTap: () => _showPlaceholder('Trakt'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],
              if (showGeneral) ...<Widget>[
                const _SettingsSectionLabel('GENERAL'),
                _SettingsGroupCard(
                  children: <Widget>[
                    _SettingsActionTile(
                      icon: Icons.palette_rounded,
                      title: 'Layout',
                      subtitle: 'Home structure and poster styles',
                      onTap: () => _showPlaceholder('Layout'),
                    ),
                    _SettingsActionTile(
                      icon: Icons.extension_rounded,
                      title: 'Content & Discovery',
                      subtitle: 'Manage addons and discovery sources.',
                      onTap: _openAddons,
                    ),
                    _SettingsActionTile(
                      icon: Icons.cloud_download_rounded,
                      title: 'Downloads',
                      subtitle: 'Manage your downloaded movies and episodes.',
                      onTap: () => _showPlaceholder('Downloads'),
                    ),
                    _SettingsActionTile(
                      icon: Icons.rocket_launch_rounded,
                      title: 'Torboxers',
                      subtitle: 'Search streams and imported engines',
                      onTap: _openTorboxers,
                    ),
                    _SettingsActionTile(
                      icon: Icons.wifi_tethering_rounded,
                      title: 'Indexer Status',
                      subtitle: 'Check Torrentio source health',
                      onTap: _openIndexerStatus,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SettingsSectionLabel('INTEGRATIONS'),
                _IntegrationPanel(
                  textFieldKey: const ValueKey<String>('torbox-api-key-field'),
                  saveButtonKey:
                      const ValueKey<String>('torbox-api-key-save-button'),
                  title: 'TorBox',
                  subtitle:
                      'Used by source resolving, library, magnet import, and player tools.',
                  icon: Icons.dns_rounded,
                  controller: _apiKeyController,
                  hintText: 'TorBox API key',
                  saving: _saving,
                  connected: _settings.torBoxApiKey != null,
                  onSave: _saveApiKey,
                  onRemove: _removeApiKey,
                  onRefresh: _load,
                  extraActions: <Widget>[
                    FilledButton.tonal(
                      onPressed: _openMagnet,
                      child: const Text('Open Magnet'),
                    ),
                  ],
                  status: _torBoxStatus == null
                      ? null
                      : _TorBoxStatusBanner(
                          message: _torBoxStatus!,
                          error: _user == null,
                        ),
                ),
                const SizedBox(height: 14),
                _IntegrationPanel(
                  textFieldKey:
                      const ValueKey<String>('realdebrid-api-key-field'),
                  saveButtonKey:
                      const ValueKey<String>('realdebrid-api-key-save-button'),
                  title: 'Real-Debrid',
                  subtitle:
                      'Optional RD resolver. Sources marked RD+ can resolve directly through Real-Debrid.',
                  icon: Icons.bolt_rounded,
                  controller: _realDebridKeyController,
                  hintText: 'Real-Debrid API token',
                  saving: _saving,
                  connected: _settings.realDebridApiKey != null,
                  onSave: _saveRealDebridApiKey,
                  onRemove: _removeRealDebridApiKey,
                  onRefresh: _load,
                  status: _realDebridStatus == null
                      ? null
                      : _TorBoxStatusBanner(
                          message: _realDebridStatus!,
                          error: _realDebridUser == null,
                        ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Preferred resolver',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          ChoiceChip(
                            label: const Text('TorBox first'),
                            selected:
                                _settings.preferredDebridProvider == 'torbox',
                            onSelected: (_) => _setPreferredDebrid('torbox'),
                          ),
                          ChoiceChip(
                            label: const Text('Real-Debrid first'),
                            selected: _settings.preferredDebridProvider ==
                                'realdebrid',
                            onSelected: (_) =>
                                _setPreferredDebrid('realdebrid'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (_user != null || _realDebridUser != null) ...<Widget>[
                const SizedBox(height: 22),
                const _SettingsSectionLabel('CONNECTED ACCOUNTS'),
                _SettingsGroupCard(
                  children: <Widget>[
                    if (_user != null)
                      _SettingsInfoTile(
                        title: 'TorBox account',
                        rows: <String>[
                          _user!.email,
                          _user!.plan,
                          if (_user!.hasSlotInfo)
                            'Slots ${_user!.usedSlots}/${_user!.totalSlots}',
                          if ((_user!.premiumExpiresAt ?? '').isNotEmpty)
                            'Renews ${_user!.premiumExpiresAt}',
                        ],
                      ),
                    if (_realDebridUser != null)
                      _SettingsInfoTile(
                        title: 'Real-Debrid account',
                        rows: <String>[
                          _realDebridUser!.username,
                          if (_realDebridUser!.email.isNotEmpty)
                            _realDebridUser!.email,
                          _realDebridUser!.type,
                          if ((_realDebridUser!.expiration ?? '').isNotEmpty)
                            'Expires ${_realDebridUser!.expiration}',
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'TorBox library (${_torrents.length})',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
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

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.label);

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

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.children});

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

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: (accent ?? Colors.white)
              .withOpacity(accent == null ? 0.08 : 0.22),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.text, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          height: 1.25,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (String row) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                row,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegrationPanel extends StatelessWidget {
  const _IntegrationPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.controller,
    required this.hintText,
    required this.textFieldKey,
    required this.saveButtonKey,
    required this.saving,
    required this.connected,
    required this.onSave,
    required this.onRemove,
    required this.onRefresh,
    this.extraActions = const <Widget>[],
    this.status,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final TextEditingController controller;
  final String hintText;
  final Key textFieldKey;
  final Key saveButtonKey;
  final bool saving;
  final bool connected;
  final VoidCallback onSave;
  final VoidCallback onRemove;
  final VoidCallback onRefresh;
  final List<Widget> extraActions;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connected ? 'Connected' : 'Not connected',
                      style: TextStyle(
                        color: connected
                            ? const Color(0xFFBBF7D0)
                            : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: 12),
          TextField(
            key: textFieldKey,
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              hintText: hintText,
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
                key: saveButtonKey,
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.text,
                  foregroundColor: AppColors.background,
                ),
                child: Text(saving ? 'Saving...' : 'Save'),
              ),
              FilledButton.tonal(
                onPressed: connected ? onRemove : null,
                child: const Text('Remove'),
              ),
              FilledButton.tonal(
                onPressed: onRefresh,
                child: const Text('Refresh'),
              ),
              ...extraActions,
            ],
          ),
          if (status != null) ...<Widget>[
            const SizedBox(height: 12),
            status!,
          ],
        ],
      ),
    );
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
