import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/stream_catalog_service.dart';
import '../services/stremio_addons_service.dart';
import '../services/torbox_api_service.dart';
import '../services/torbox_playlist_repository.dart';
import '../theme/app_colors.dart';
import 'addons_screen.dart';
import 'indexer_status_screen.dart';
import 'video_player_screen.dart';

class TorboxersScreen extends StatefulWidget {
  TorboxersScreen({
    super.key,
    this.seedTitle,
    this.posterPath,
    this.mediaType,
    this.imdbId,
    this.tmdbId,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeName,
    StreamCatalogService? streamCatalogService,
    StremioAddonsService? addonsService,
    TorBoxApiService? torBoxApiService,
    TorboxPlaylistRepository? playlistRepository,
    AppSettingsRepository? settingsRepository,
  })  : streamCatalogService = streamCatalogService ?? const StreamCatalogService(),
        addonsService = addonsService ?? StremioAddonsService(),
        torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        playlistRepository = playlistRepository ?? TorboxPlaylistRepository(),
        settingsRepository = settingsRepository ?? AppSettingsRepository();

  final String? seedTitle;
  final String? posterPath;
  final String? mediaType;
  final String? imdbId;
  final int? tmdbId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;
  final StreamCatalogService streamCatalogService;
  final StremioAddonsService addonsService;
  final TorBoxApiService torBoxApiService;
  final TorboxPlaylistRepository playlistRepository;
  final AppSettingsRepository settingsRepository;

  @override
  State<TorboxersScreen> createState() => _TorboxersScreenState();
}

class _TorboxersScreenState extends State<TorboxersScreen> {
  final TextEditingController _queryController = TextEditingController();
  AppSettings _settings = const AppSettings();
  List<StreamSource> _results = const <StreamSource>[];
  List<StreamSource> _playlist = const <StreamSource>[];
  List<TorBoxTorrent> _library = const <TorBoxTorrent>[];
  bool _loadingSearch = false;
  bool _loadingLibrary = true;
  bool _loadingPlaylist = true;
  String? _searchMessage;

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.seedTitle ?? '';
    _bootstrap();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      widget.playlistRepository.getItems(),
      widget.torBoxApiService.getUserTorrents(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = settings;
      _playlist = results[0] as List<StreamSource>;
      _library = results[1] as List<TorBoxTorrent>;
      _loadingLibrary = false;
      _loadingPlaylist = false;
    });

    if ((widget.imdbId ?? '').isNotEmpty) {
      await _search();
    } else {
      setState(() {
        _searchMessage =
            'Open Torboxers from a movie or episode detail screen to search real stream sources by IMDb ID.';
      });
    }
  }

  Future<void> _search() async {
    final String? imdbId = widget.imdbId;
    final String? mediaType = widget.mediaType;
    if (imdbId == null || imdbId.isEmpty || mediaType == null) {
      setState(() {
        _searchMessage =
            'This screen needs a title with an IMDb ID to query Torrentio and any installed addons.';
      });
      return;
    }

    setState(() {
      _loadingSearch = true;
      _searchMessage = null;
    });

    final List<StreamSource> merged = <StreamSource>[];
    final Set<String> seen = <String>{};

    try {
      final List<StreamSource> indexerResults =
          await widget.streamCatalogService.getBuiltInStreams(
        imdbId: imdbId,
        mediaType: mediaType,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
      );
      for (final StreamSource item in indexerResults) {
        if (seen.add(item.id)) {
          merged.add(item);
        }
      }

      if (_settings.useAddons) {
        final String streamId = mediaType == 'tv'
            ? '$imdbId:${widget.seasonNumber ?? 1}:${widget.episodeNumber ?? 1}'
            : imdbId;
        final List<StreamSource> addonResults =
            await widget.addonsService.getStreams(
          mediaType: mediaType,
          streamId: streamId,
        );
        for (final StreamSource item in addonResults) {
          if (seen.add(item.id)) {
            merged.add(item);
          }
        }
      }

      merged.sort((StreamSource a, StreamSource b) {
        if (a.isCached == b.isCached) {
          return a.sourceDisplayName.compareTo(b.sourceDisplayName);
        }
        return a.isCached ? -1 : 1;
      });
    } catch (error) {
      setState(() {
        _searchMessage = error.toString();
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _results = merged;
      _loadingSearch = false;
      _searchMessage = merged.isEmpty
          ? 'No sources came back for this title with the current settings.'
          : _searchMessage;
    });
  }

  Future<void> _refreshPlaylist() async {
    final List<StreamSource> items = await widget.playlistRepository.getItems();
    if (!mounted) {
      return;
    }
    setState(() {
      _playlist = items;
    });
  }

  Future<void> _refreshLibrary() async {
    final List<TorBoxTorrent> items = await widget.torBoxApiService.getUserTorrents();
    if (!mounted) {
      return;
    }
    setState(() {
      _library = items;
    });
  }

  Future<void> _addToPlaylist(StreamSource source) async {
    await widget.playlistRepository.addItem(source);
    await _refreshPlaylist();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to playlist.')),
    );
  }

  Future<void> _removeFromPlaylist(StreamSource source) async {
    await widget.playlistRepository.removeItem(source.id);
    await _refreshPlaylist();
  }

  Future<void> _addToTorBox(StreamSource source) async {
    if (source.infoHash == null || source.infoHash!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This source does not expose a torrent hash.')),
      );
      return;
    }

    final TorBoxTorrent? torrent = await widget.torBoxApiService.addTorrent(source.infoHash!);
    await _refreshLibrary();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          torrent == null
              ? 'Could not add that source to TorBox.'
              : 'Added "${torrent.name}" to TorBox.',
        ),
      ),
    );
  }

  Future<void> _playSource(StreamSource source) async {
    if (source.isDirectUrl) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => VideoPlayerScreen(
            title: source.title,
            posterUrl: widget.posterPath,
            tmdbId: widget.tmdbId,
            mediaType: widget.mediaType,
            seasonNumber: widget.seasonNumber,
            episodeNumber: widget.episodeNumber,
            episodeName: widget.episodeName,
            initialVideoUrl: source.directUrl,
            provider: source.sourceDisplayName,
          ),
        ),
      );
      return;
    }

    if (source.infoHash == null || source.infoHash!.isEmpty) {
      return;
    }

    final TorBoxTorrent? torrent = await widget.torBoxApiService.addTorrent(source.infoHash!);
    if (torrent == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not prepare this source in TorBox.')),
      );
      return;
    }

    await _refreshLibrary();
    if (!mounted) {
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => VideoPlayerScreen(
          title: widget.episodeName ?? widget.seedTitle ?? torrent.name,
          posterUrl: widget.posterPath,
          tmdbId: widget.tmdbId,
          mediaType: widget.mediaType,
          seasonNumber: widget.seasonNumber,
          episodeNumber: widget.episodeNumber,
          episodeName: widget.episodeName,
          torrentHash: torrent.hash,
          torrentId: torrent.id,
          initialFiles: torrent.files,
          initialFileId: torrent.files.isNotEmpty ? torrent.files.first.id : null,
          provider: source.sourceDisplayName,
        ),
      ),
    );
  }

  void _openLibraryTorrent(TorBoxTorrent torrent) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => VideoPlayerScreen(
          title: torrent.name,
          torrentHash: torrent.hash,
          torrentId: torrent.id,
          initialFiles: torrent.files,
          initialFileId: torrent.files.isNotEmpty ? torrent.files.first.id : null,
          provider: 'torbox',
        ),
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

  void _openSourceStatus() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const IndexerStatusScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String heading = widget.episodeName ??
        widget.seedTitle ??
        'Torboxers';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Torboxers'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Search'),
              Tab(text: 'Playlist'),
              Tab(text: 'Library'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0xFF111111),
                    Color(0xFF070707),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    heading,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      const _HeaderChip(label: 'Torrentio'),
                      _HeaderChip(
                        label: _settings.useAddons ? 'Addons on' : 'Addons off',
                      ),
                      if ((widget.imdbId ?? '').isNotEmpty)
                        _HeaderChip(label: widget.imdbId!),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _buildSearchTab(),
                  _buildPlaylistTab(),
                  _buildLibraryTab(),
                  _buildSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return RefreshIndicator(
      onRefresh: _search,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          TextField(
            controller: _queryController,
            readOnly: true,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              labelText: 'Selected title',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadingSearch ? null : _search,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.text,
              foregroundColor: AppColors.background,
            ),
            child: Text(_loadingSearch ? 'Searching...' : 'Search sources'),
          ),
          const SizedBox(height: 18),
          if (_loadingSearch)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.text),
              ),
            )
          else if (_results.isEmpty)
            _SearchEmptyState(message: _searchMessage)
          else
            ..._results.map(
              (StreamSource source) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SourceCard(
                  source: source,
                  onPlay: () => _playSource(source),
                  onAddToPlaylist: () => _addToPlaylist(source),
                  onAddToTorBox: () => _addToTorBox(source),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistTab() {
    if (_loadingPlaylist) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.text),
      );
    }

    if (_playlist.isEmpty) {
      return const _PlaylistEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshPlaylist,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: _playlist
            .map(
              (StreamSource source) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SourceCard(
                  source: source,
                  onPlay: () => _playSource(source),
                  onAddToPlaylist: () => _removeFromPlaylist(source),
                  onAddToTorBox: () => _addToTorBox(source),
                  playlistMode: true,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildLibraryTab() {
    if (_loadingLibrary) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.text),
      );
    }

    if (_library.isEmpty) {
      return const _LibraryEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshLibrary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: _library
            .map(
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
                      Text(
                        torrent.name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _HeaderChip(label: '${torrent.progress.round()}%'),
                          _HeaderChip(label: _formatBytes(torrent.size)),
                          _HeaderChip(
                            label: torrent.downloadState.isEmpty
                                ? 'Queued'
                                : torrent.downloadState,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => _openLibraryTorrent(torrent),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.08),
                          foregroundColor: AppColors.text,
                        ),
                        child: const Text('Open player tools'),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
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
                'Current search mode',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Built-in source: Torrentio\nAddons merged: ${_settings.useAddons ? 'Yes' : 'No'}',
                style: const TextStyle(color: AppColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsJumpCard(
          title: 'Source status',
          subtitle: 'Check Torrentio health and review how built-in search works.',
          onTap: _openSourceStatus,
        ),
        const SizedBox(height: 12),
        _SettingsJumpCard(
          title: 'Manage addons',
          subtitle: 'Install Stremio manifests that Torboxers can merge into search.',
          onTap: _openAddons,
        ),
      ],
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

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label});

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

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.onPlay,
    required this.onAddToPlaylist,
    required this.onAddToTorBox,
    this.playlistMode = false,
  });

  final StreamSource source;
  final VoidCallback onPlay;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onAddToTorBox;
  final bool playlistMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      source.title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _HeaderChip(label: source.sourceDisplayName),
                        _HeaderChip(label: source.quality),
                        if (source.sizeLabel.isNotEmpty)
                          _HeaderChip(label: source.sizeLabel),
                        if (source.isCached) const _HeaderChip(label: 'Cached'),
                        if (source.isDirectUrl) const _HeaderChip(label: 'Direct URL'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (source.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              source.description,
              style: const TextStyle(color: AppColors.textMuted, height: 1.45),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.text,
                  foregroundColor: AppColors.background,
                ),
                child: const Text('Play now'),
              ),
              FilledButton.tonal(
                onPressed: onAddToPlaylist,
                child: Text(playlistMode ? 'Remove' : 'Add to playlist'),
              ),
              if (!source.isDirectUrl)
                FilledButton.tonal(
                  onPressed: onAddToTorBox,
                  child: const Text('Add to TorBox'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.search_outlined, color: AppColors.textMuted, size: 36),
          const SizedBox(height: 12),
          const Text(
            'No results yet',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message ??
                'Start a search from a movie or episode detail screen and Torboxers will aggregate Torrentio plus any enabled addons here.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PlaylistEmptyState extends StatelessWidget {
  const _PlaylistEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.playlist_add_outlined, color: AppColors.textMuted, size: 36),
              SizedBox(height: 12),
              Text(
                'Playlist is empty.',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Save stream candidates here and revisit them later without running the search again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.cloud_off_outlined, color: AppColors.textMuted, size: 36),
              SizedBox(height: 12),
              Text(
                'TorBox library is empty.',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Add a source to TorBox from the search tab or the Magnet screen and it will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsJumpCard extends StatelessWidget {
  const _SettingsJumpCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted, height: 1.45),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
