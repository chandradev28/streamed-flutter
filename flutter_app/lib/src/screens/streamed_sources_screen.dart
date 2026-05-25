import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/episode_parser.dart';
import '../services/real_debrid_api_service.dart';
import '../services/stream_catalog_service.dart';
import '../services/stremio_addons_service.dart';
import '../services/torbox_api_service.dart';
import '../theme/app_colors.dart';
import 'video_player_screen.dart';

class StreamedSourcesScreen extends StatefulWidget {
  StreamedSourcesScreen({
    super.key,
    required this.title,
    this.posterPath,
    required this.mediaType,
    required this.imdbId,
    this.tmdbId,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeName,
    StreamCatalogService? streamCatalogService,
    StremioAddonsService? addonsService,
    TorBoxApiService? torBoxApiService,
    RealDebridApiService? realDebridApiService,
    AppSettingsRepository? settingsRepository,
  })  : streamCatalogService = streamCatalogService ?? StreamCatalogService(),
        addonsService = addonsService ?? StremioAddonsService(),
        torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        realDebridApiService = realDebridApiService ?? RealDebridApiService(),
        settingsRepository = settingsRepository ?? AppSettingsRepository();

  final String title;
  final String? posterPath;
  final String mediaType;
  final String imdbId;
  final int? tmdbId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;
  final StreamCatalogService streamCatalogService;
  final StremioAddonsService addonsService;
  final TorBoxApiService torBoxApiService;
  final RealDebridApiService realDebridApiService;
  final AppSettingsRepository settingsRepository;

  @override
  State<StreamedSourcesScreen> createState() => _StreamedSourcesScreenState();
}

class _StreamedSourcesScreenState extends State<StreamedSourcesScreen> {
  AppSettings _settings = const AppSettings();
  List<AddonManifest> _addons = const <AddonManifest>[];
  List<StreamSource> _results = const <StreamSource>[];
  bool _loading = true;
  String? _message;
  String? _selectedSource;
  bool _cachedOnly = false;
  Map<String, int> _sourceCounts = const <String, int>{};
  Map<String, String> _sourceErrors = const <String, String>{};

  bool get _isEpisodeContext =>
      widget.mediaType == 'tv' &&
      widget.seasonNumber != null &&
      widget.episodeNumber != null;

  List<String> get _availableSources {
    final List<String> values = _results
        .map((StreamSource source) => source.sourceDisplayName)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  List<StreamSource> get _visibleResults {
    return _results
        .where(
          (StreamSource source) =>
              (_selectedSource == null ||
                  source.sourceDisplayName == _selectedSource) &&
              (!_cachedOnly || source.isCached),
        )
        .toList(growable: false);
  }

  List<String> get _visibleGroupNames {
    final List<String> values = _visibleResults
        .map((StreamSource source) => source.sourceDisplayName)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  bool _isSeasonPackSource(StreamSource source) {
    final String text = <String>[
      source.title,
      source.description,
      if (source.fileName != null) source.fileName!,
    ].join('\n');
    return isSeasonPackTitle(text);
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    final List<AddonManifest> addons =
        await widget.addonsService.getInstalledAddons();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _addons = addons;
    });
    await _search();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    final List<StreamSource> merged = <StreamSource>[];
    final Set<String> seen = <String>{};
    final Map<String, int> sourceCounts = <String, int>{};
    final Map<String, String> sourceErrors = <String, String>{};

    try {
      final List<AddonManifest> addons =
          await widget.addonsService.getInstalledAddons();
      if (mounted) {
        setState(() {
          _addons = addons;
        });
      }

      final bool hasEnabledStreamAddon = addons.any(
        (AddonManifest addon) => addon.enabled && addon.hasStreamResource,
      );
      if (!hasEnabledStreamAddon) {
        _message = 'Install and enable a stream addon to search Streamed.';
      }

      if (hasEnabledStreamAddon) {
        final String streamId = widget.mediaType == 'tv'
            ? '${widget.imdbId}:${widget.seasonNumber ?? 1}:${widget.episodeNumber ?? 1}'
            : widget.imdbId;
        final AddonSearchResult addonSearch =
            await widget.addonsService.searchStreamsDetailed(
          mediaType: widget.mediaType,
          streamId: streamId,
        );
        sourceCounts.addAll(addonSearch.diagnostics.sourceCounts);
        sourceErrors.addAll(addonSearch.diagnostics.sourceErrors);
        final List<StreamSource> addonStreams =
            await widget.streamCatalogService.annotateCacheStatus(
          addonSearch.streams,
        );
        for (final StreamSource item in addonStreams) {
          if (seen.add(item.id)) {
            merged.add(item);
          }
        }
      }

      if (merged.isEmpty) {
        _message ??= 'No addon streams found for this title.';
      }

      merged.sort((StreamSource a, StreamSource b) {
        if (a.isCached == b.isCached) {
          return a.sourceDisplayName.compareTo(b.sourceDisplayName);
        }
        return a.isCached ? -1 : 1;
      });
    } catch (error) {
      _message = error.toString();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _results = merged;
      _selectedSource = null;
      _cachedOnly = false;
      _sourceCounts = sourceCounts;
      _sourceErrors = sourceErrors;
      _loading = false;
      _message = merged.isEmpty
          ? (_message ?? 'No sources came back for this title.')
          : _message;
    });
  }

  Future<void> _playSource(StreamSource source) async {
    if (source.hasTorrentSource && _settings.resolvePlayableLinksEnabled) {
      final bool played = await _playResolvedTorrentSource(source);
      if (played) {
        return;
      }
    }

    if (source.isDirectUrl) {
      _openDirectUrl(source);
      return;
    }

    if (!source.hasTorrentSource) {
      return;
    }

    if (!_settings.resolvePlayableLinksEnabled) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enable Connected Services > Resolve playable links to play torrent sources.',
          ),
        ),
      );
      return;
    }

    final bool played = await _playResolvedTorrentSource(source);
    if (!mounted || played) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not prepare this source in a connected service.'),
      ),
    );
  }

  void _openDirectUrl(StreamSource source) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => VideoPlayerScreen(
          title: widget.episodeName ?? widget.title,
          posterUrl: widget.posterPath,
          tmdbId: widget.tmdbId,
          mediaType: widget.mediaType,
          seasonNumber: widget.seasonNumber,
          episodeNumber: widget.episodeNumber,
          episodeName: widget.episodeName,
          initialVideoUrl: source.directUrl,
          provider: source.sourceDisplayName,
          streamHeaders: source.streamHeaders,
        ),
      ),
    );
  }

  Future<bool> _playResolvedTorrentSource(StreamSource source) async {
    final String preferred = _preferredProviderFor(source);
    if (preferred == 'realdebrid') {
      final bool played = await _playViaRealDebrid(source);
      if (played) {
        return true;
      }
    }

    final TorBoxTorrent? torrent = await widget.torBoxApiService.addTorrent(
      source.magnetUri ?? source.infoHash!,
    );
    if (torrent == null) {
      if (source.isRealDebridCached) {
        final bool played = await _playViaRealDebrid(source);
        if (played) {
          return true;
        }
      }
      return false;
    }

    if (!mounted) {
      return true;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => VideoPlayerScreen(
          title: widget.episodeName ?? widget.title,
          posterUrl: widget.posterPath,
          tmdbId: widget.tmdbId,
          mediaType: widget.mediaType,
          seasonNumber: widget.seasonNumber,
          episodeNumber: widget.episodeNumber,
          episodeName: widget.episodeName,
          torrentHash: torrent.hash,
          torrentId: torrent.id,
          initialFiles: torrent.files,
          initialFileId: _preferredInitialFileId(torrent.files, source),
          initialFileIndex: source.fileIndex,
          initialFileName: source.fileName,
          provider: source.sourceDisplayName,
        ),
      ),
    );
    return true;
  }

  String _preferredProviderFor(StreamSource source) {
    final String preferred = _settings.preferredDebridProvider;
    if (preferred == 'realdebrid' && source.isRealDebridCached) {
      return 'realdebrid';
    }
    if (preferred == 'torbox' && source.isTorBoxCached) {
      return 'torbox';
    }
    if (source.isTorBoxCached) {
      return 'torbox';
    }
    if (source.isRealDebridCached) {
      return 'realdebrid';
    }
    return preferred;
  }

  Future<bool> _playViaRealDebrid(StreamSource source) async {
    try {
      final RealDebridResolvedLink? link =
          await widget.realDebridApiService.resolveSource(
        source: source,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
      );
      if (!mounted || link == null || link.url.isEmpty) {
        return false;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => VideoPlayerScreen(
            title: link.filename ?? widget.episodeName ?? widget.title,
            posterUrl: widget.posterPath,
            tmdbId: widget.tmdbId,
            mediaType: widget.mediaType,
            seasonNumber: widget.seasonNumber,
            episodeNumber: widget.episodeNumber,
            episodeName: widget.episodeName,
            initialVideoUrl: link.url,
            provider: 'Real-Debrid',
          ),
        ),
      );
      return true;
    } on RealDebridApiException catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.detail)),
      );
      return false;
    }
  }

  Future<void> _addToTorBox(StreamSource source) async {
    if (source.infoHash == null || source.infoHash!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This source does not expose a torrent hash.'),
        ),
      );
      return;
    }

    final TorBoxTorrent? torrent = await widget.torBoxApiService.addTorrent(
      source.magnetUri ?? source.infoHash!,
    );
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

  int? _preferredInitialFileId(
    List<TorBoxTorrentFile> files,
    StreamSource source,
  ) {
    if (files.isEmpty) {
      return null;
    }

    final int? fileIndex = source.fileIndex;
    if (fileIndex != null && fileIndex >= 0 && fileIndex < files.length) {
      return files[fileIndex].id;
    }

    final String? fileName = source.fileName;
    if (fileName != null && fileName.trim().isNotEmpty) {
      final String normalizedTarget = _normalizeFileName(fileName);
      for (final TorBoxTorrentFile file in files) {
        if (_normalizeFileName(file.name) == normalizedTarget ||
            _normalizeFileName(file.displayName) == normalizedTarget) {
          return file.id;
        }
      }
    }

    final List<int> videoIndices = getAllVideoFiles(files);
    if (videoIndices.isNotEmpty) {
      return files[videoIndices.first].id;
    }
    return files.first.id;
  }

  String _normalizeFileName(String value) {
    return value.split(RegExp(r'[/\\]')).last.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final int cachedCount =
        _results.where((StreamSource source) => source.isCached).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sources'),
      ),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.episodeName ?? widget.title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _StreamedHeaderChip(
                        label:
                            '${_addons.where((AddonManifest addon) => addon.enabled && addon.hasStreamResource).length} enabled addons',
                      ),
                      if (_isEpisodeContext)
                        _StreamedHeaderChip(
                          label:
                              'S${widget.seasonNumber}E${widget.episodeNumber}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _loading ? null : _search,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.text,
                      foregroundColor: AppColors.background,
                    ),
                    child: Text(_loading ? 'Searching...' : 'Refresh sources'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_sourceCounts.isNotEmpty ||
                _sourceErrors.isNotEmpty) ...<Widget>[
              _DiagnosticsCard(
                counts: _sourceCounts,
                errors: _sourceErrors,
              ),
              const SizedBox(height: 12),
            ],
            if (_availableSources.isNotEmpty) ...<Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _SourceFilterChip(
                      label: 'All (${_results.length})',
                      selected: _selectedSource == null && !_cachedOnly,
                      onTap: () {
                        setState(() {
                          _selectedSource = null;
                          _cachedOnly = false;
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _SourceFilterChip(
                        label: 'Cached only ($cachedCount)',
                        selected: _cachedOnly,
                        onTap: () {
                          setState(() {
                            _cachedOnly = !_cachedOnly;
                          });
                        },
                      ),
                    ),
                    ..._availableSources.map(
                      (String sourceName) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _SourceFilterChip(
                          label:
                              '$sourceName (${_results.where((StreamSource item) => item.sourceDisplayName == sourceName).length})',
                          selected: _selectedSource == sourceName,
                          onTap: () {
                            setState(() {
                              _selectedSource = _selectedSource == sourceName
                                  ? null
                                  : sourceName;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.text),
                ),
              )
            else if (_results.isEmpty)
              _EmptyState(message: _message)
            else if (_visibleResults.isEmpty)
              _EmptyState(
                message: _cachedOnly
                    ? 'No cached streams match the current filter.'
                    : _message,
              )
            else
              ..._visibleGroupNames.map(
                (String sourceName) => _SourceResultGroup(
                  sourceName: sourceName,
                  sources: _visibleResults
                      .where(
                        (StreamSource source) =>
                            source.sourceDisplayName == sourceName,
                      )
                      .toList(growable: false),
                  isEpisodeContext: _isEpisodeContext,
                  isSeasonPackSource: _isSeasonPackSource,
                  onPlay: _playSource,
                  onAddToTorBox: _addToTorBox,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SourceResultGroup extends StatelessWidget {
  const _SourceResultGroup({
    required this.sourceName,
    required this.sources,
    required this.isEpisodeContext,
    required this.isSeasonPackSource,
    required this.onPlay,
    required this.onAddToTorBox,
  });

  final String sourceName;
  final List<StreamSource> sources;
  final bool isEpisodeContext;
  final bool Function(StreamSource source) isSeasonPackSource;
  final ValueChanged<StreamSource> onPlay;
  final ValueChanged<StreamSource> onAddToTorBox;

  @override
  Widget build(BuildContext context) {
    final List<StreamSource> episodeSources = sources
        .where((StreamSource source) => !isSeasonPackSource(source))
        .toList(growable: false);
    final List<StreamSource> seasonPacks = sources
        .where((StreamSource source) => isSeasonPackSource(source))
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHeader(
            title: sourceName,
            subtitle:
                '${sources.length} result${sources.length == 1 ? '' : 's'} from this addon.',
          ),
          const SizedBox(height: 10),
          if (!isEpisodeContext)
            ...sources.map(
              (StreamSource source) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StreamedSourceCard(
                  source: source,
                  onPlay: () => onPlay(source),
                  onAddToTorBox: () => onAddToTorBox(source),
                ),
              ),
            )
          else ...<Widget>[
            if (episodeSources.isNotEmpty) ...<Widget>[
              const _SmallGroupLabel('Episode Sources'),
              ...episodeSources.map(
                (StreamSource source) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StreamedSourceCard(
                    source: source,
                    onPlay: () => onPlay(source),
                    onAddToTorBox: () => onAddToTorBox(source),
                  ),
                ),
              ),
            ],
            if (seasonPacks.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              const _SmallGroupLabel('Season Packs'),
              ...seasonPacks.map(
                (StreamSource source) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StreamedSourceCard(
                    source: source,
                    onPlay: () => onPlay(source),
                    onAddToTorBox: () => onAddToTorBox(source),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SmallGroupLabel extends StatelessWidget {
  const _SmallGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _StreamedSourceCard extends StatelessWidget {
  const _StreamedSourceCard({
    required this.source,
    required this.onPlay,
    required this.onAddToTorBox,
  });

  final StreamSource source;
  final VoidCallback onPlay;
  final VoidCallback onAddToTorBox;

  @override
  Widget build(BuildContext context) {
    final bool seasonPack = isSeasonPackTitle(
      <String>[
        source.title,
        source.description,
        if (source.fileName != null) source.fileName!,
      ].join('\n'),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
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
              _StreamedHeaderChip(label: source.sourceDisplayName),
              _StreamedHeaderChip(label: source.quality),
              if (source.sizeLabel.isNotEmpty)
                _StreamedHeaderChip(label: source.sizeLabel),
              if (source.cacheProvider != null)
                _StreamedHeaderChip(label: source.cacheProvider!)
              else if (source.isCached)
                const _StreamedHeaderChip(label: 'Cached'),
              if (seasonPack) const _StreamedHeaderChip(label: 'Season pack'),
              if (source.isDirectUrl)
                const _StreamedHeaderChip(label: 'Direct URL'),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({
    required this.counts,
    required this.errors,
  });

  final Map<String, int> counts;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    final List<String> keys = <String>{...counts.keys, ...errors.keys}.toList()
      ..sort();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Source diagnostics',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...keys.map(
            (String key) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      key,
                      style: const TextStyle(color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    counts[key]?.toString() ?? '0',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          if (errors.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            ...errors.entries.map(
              (MapEntry<String, String> entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceFilterChip extends StatelessWidget {
  const _SourceFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.text : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.background : AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StreamedHeaderChip extends StatelessWidget {
  const _StreamedHeaderChip({required this.label});

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

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message});

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
          const Icon(Icons.search_outlined,
              color: AppColors.textMuted, size: 36),
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
            message ?? 'No sources came back for this title.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
