import 'package:flutter/material.dart';

import '../models/engine_models.dart';
import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/engine_runtime_service.dart';
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
    EngineRuntimeService? engineRuntimeService,
  })  : streamCatalogService =
            streamCatalogService ?? const StreamCatalogService(),
        addonsService = addonsService ?? StremioAddonsService(),
        torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        playlistRepository = playlistRepository ?? TorboxPlaylistRepository(),
        settingsRepository = settingsRepository ?? AppSettingsRepository(),
        engineRuntimeService = engineRuntimeService ?? EngineRuntimeService();

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
  final EngineRuntimeService engineRuntimeService;

  @override
  State<TorboxersScreen> createState() => _TorboxersScreenState();
}

class _TorboxersScreenState extends State<TorboxersScreen> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _engineQueryController = TextEditingController();
  AppSettings _settings = const AppSettings();
  List<StreamSource> _results = const <StreamSource>[];
  List<StreamSource> _engineResults = const <StreamSource>[];
  List<StreamSource> _playlist = const <StreamSource>[];
  List<TorBoxTorrent> _library = const <TorBoxTorrent>[];
  List<AddonManifest> _addons = const <AddonManifest>[];
  List<ImportedEngine> _importedEngines = const <ImportedEngine>[];
  List<RemoteEngineInfo> _catalogEngines = const <RemoteEngineInfo>[];
  bool _loadingSearch = false;
  bool _loadingEngineSearch = false;
  bool _loadingLibrary = true;
  bool _loadingPlaylist = true;
  bool _loadingEngineCatalog = true;
  bool _importingRecommendedEngines = false;
  String? _searchMessage;
  String? _engineMessage;
  String? _engineCatalogMessage;
  String? _selectedSource;
  String? _selectedEngineSource;
  Map<String, int> _sourceCounts = const <String, int>{};
  Map<String, String> _sourceErrors = const <String, String>{};
  Map<String, int> _engineCounts = const <String, int>{};
  Map<String, String> _engineErrors = const <String, String>{};

  List<String> get _availableSources {
    final List<String> values = _results
        .map((StreamSource source) => source.sourceDisplayName)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  List<StreamSource> get _visibleResults {
    if (_selectedSource == null) {
      return _results;
    }
    return _results
        .where((StreamSource source) =>
            source.sourceDisplayName == _selectedSource)
        .toList(growable: false);
  }

  List<String> get _availableEngineSources {
    final List<String> values = _engineResults
        .map((StreamSource source) => source.sourceDisplayName)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  List<StreamSource> get _visibleEngineResults {
    if (_selectedEngineSource == null) {
      return _engineResults;
    }
    return _engineResults
        .where(
          (StreamSource source) =>
              source.sourceDisplayName == _selectedEngineSource,
        )
        .toList(growable: false);
  }

  List<RemoteEngineInfo> get _availableCatalogEngines {
    final Set<String> importedIds =
        _importedEngines.map((ImportedEngine engine) => engine.id).toSet();
    return _catalogEngines
        .where((RemoteEngineInfo engine) => !importedIds.contains(engine.id))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.seedTitle ?? '';
    _engineQueryController.text = widget.seedTitle ?? '';
    _bootstrap();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _engineQueryController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final AppSettings settings =
          await widget.settingsRepository.loadSettings();
      final List<dynamic> results =
          await Future.wait<dynamic>(<Future<dynamic>>[
        widget.playlistRepository.getItems(),
        widget.torBoxApiService.getUserTorrents(),
        widget.addonsService.getInstalledAddons(),
        widget.engineRuntimeService.getImportedEngines(),
        widget.engineRuntimeService.getCatalog(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _settings = settings;
        _playlist = results[0] as List<StreamSource>;
        _library = results[1] as List<TorBoxTorrent>;
        _addons = results[2] as List<AddonManifest>;
        _importedEngines = results[3] as List<ImportedEngine>;
        _catalogEngines = results[4] as List<RemoteEngineInfo>;
        _loadingLibrary = false;
        _loadingPlaylist = false;
        _loadingEngineCatalog = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingLibrary = false;
        _loadingPlaylist = false;
        _loadingEngineCatalog = false;
        _engineCatalogMessage = 'Could not load the engine catalog: $error';
      });
    }

    if ((widget.imdbId ?? '').isNotEmpty) {
      await _search();
    } else {
      setState(() {
        _searchMessage =
            'Open Torboxers from a movie or episode detail screen to search real stream sources by IMDb ID.';
      });
    }

    if (_engineQueryController.text.trim().isNotEmpty) {
      await _searchEngines();
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
      sourceCounts['Torrentio'] = indexerResults.length;

      if (_settings.useAddons) {
        if (!addons.any(
          (AddonManifest addon) => addon.enabled && addon.hasStreamResource,
        )) {
          setState(() {
            _searchMessage =
                'Addons mode is enabled, but no installed addon exposes stream resources yet. Add a Stremio manifest in Settings -> Addons.';
          });
        }
        final String streamId = mediaType == 'tv'
            ? '$imdbId:${widget.seasonNumber ?? 1}:${widget.episodeNumber ?? 1}'
            : imdbId;
        final AddonSearchResult addonSearch =
            await widget.addonsService.searchStreamsDetailed(
          mediaType: mediaType,
          streamId: streamId,
        );
        final List<StreamSource> addonResults = addonSearch.streams;
        sourceCounts.addAll(addonSearch.diagnostics.sourceCounts);
        sourceErrors.addAll(addonSearch.diagnostics.sourceErrors);
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
      _selectedSource = null;
      _loadingSearch = false;
      _sourceCounts = sourceCounts;
      _sourceErrors = sourceErrors;
      _searchMessage = merged.isEmpty
          ? 'No sources came back for this title with the current settings.'
          : _searchMessage;
    });
  }

  Future<void> _searchEngines() async {
    final String query = _engineQueryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _engineMessage = 'Enter a title or keyword to search torrent engines.';
        _engineResults = const <StreamSource>[];
        _engineCounts = const <String, int>{};
        _engineErrors = const <String, String>{};
      });
      return;
    }

    setState(() {
      _loadingEngineSearch = true;
      _engineMessage = null;
    });

    try {
      final KeywordEngineSearchResult result =
          await widget.engineRuntimeService.searchKeyword(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _engineResults = result.streams;
        _engineCounts = result.diagnostics.sourceCounts;
        _engineErrors = result.diagnostics.sourceErrors;
        _selectedEngineSource = null;
        _loadingEngineSearch = false;
        _engineMessage = result.streams.isEmpty
            ? 'No imported engine results came back for that query.'
            : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingEngineSearch = false;
        _engineMessage = error.toString();
      });
    }
  }

  Future<void> _reloadEngineState({bool refreshCatalog = false}) async {
    try {
      final List<dynamic> results =
          await Future.wait<dynamic>(<Future<dynamic>>[
        widget.engineRuntimeService.getImportedEngines(),
        widget.engineRuntimeService.getCatalog(forceRefresh: refreshCatalog),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _importedEngines = results[0] as List<ImportedEngine>;
        _catalogEngines = results[1] as List<RemoteEngineInfo>;
        _loadingEngineCatalog = false;
        _engineCatalogMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingEngineCatalog = false;
        _engineCatalogMessage = error.toString();
      });
    }
  }

  Future<void> _importEngine(RemoteEngineInfo engine) async {
    setState(() {
      _engineCatalogMessage = null;
    });
    try {
      await widget.engineRuntimeService.importEngine(engine);
      await _reloadEngineState();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${engine.displayName}.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not import ${engine.displayName}: $error')),
      );
    }
  }

  Future<void> _importRecommendedEngines() async {
    setState(() {
      _importingRecommendedEngines = true;
      _engineCatalogMessage = null;
    });
    try {
      final int added =
          await widget.engineRuntimeService.importRecommendedEngines();
      await _reloadEngineState();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Recommended engines were already imported.'
                : 'Imported $added recommended engines.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import recommended engines: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _importingRecommendedEngines = false;
        });
      }
    }
  }

  Future<void> _toggleEngine(ImportedEngine engine, bool enabled) async {
    await widget.engineRuntimeService.setEnabled(engine.id, enabled);
    await _reloadEngineState();
  }

  Future<void> _changeEngineMaxResults(ImportedEngine engine, int value) async {
    await widget.engineRuntimeService.setMaxResults(engine.id, value);
    await _reloadEngineState();
  }

  Future<void> _deleteEngine(ImportedEngine engine) async {
    await widget.engineRuntimeService.deleteEngine(engine.id);
    await _reloadEngineState();
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
    final List<TorBoxTorrent> items =
        await widget.torBoxApiService.getUserTorrents();
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
        const SnackBar(
            content: Text('This source does not expose a torrent hash.')),
      );
      return;
    }

    final TorBoxTorrent? torrent =
        await widget.torBoxApiService.addTorrent(source.infoHash!);
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

    final TorBoxTorrent? torrent =
        await widget.torBoxApiService.addTorrent(source.infoHash!);
    if (torrent == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not prepare this source in TorBox.')),
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
          initialFileId:
              torrent.files.isNotEmpty ? torrent.files.first.id : null,
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
          initialFileId:
              torrent.files.isNotEmpty ? torrent.files.first.id : null,
          provider: 'torbox',
        ),
      ),
    );
  }

  void _openAddons() {
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => AddonsScreen(),
          ),
        )
        .then((_) => _reloadSettingsAndSearch());
  }

  void _openSourceStatus() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const IndexerStatusScreen(),
      ),
    );
  }

  Future<void> _reloadSettingsAndSearch() async {
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
    if ((widget.imdbId ?? '').isNotEmpty) {
      await _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String heading =
        widget.episodeName ?? widget.seedTitle ?? 'Torboxers';

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Torboxers'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Search'),
              Tab(text: 'Engines'),
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
                      _HeaderChip(
                        label:
                            '${_addons.where((AddonManifest addon) => addon.enabled && addon.hasStreamResource).length} stream addons',
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
                  _buildEnginesTab(),
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
          if (_sourceCounts.isNotEmpty || _sourceErrors.isNotEmpty) ...<Widget>[
            _DiagnosticsCard(
              title: 'Source diagnostics',
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
                    selected: _selectedSource == null,
                    onTap: () {
                      setState(() {
                        _selectedSource = null;
                      });
                    },
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
            ..._visibleResults.map(
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

  Widget _buildEnginesTab() {
    return RefreshIndicator(
      onRefresh: () => _reloadEngineState(refreshCatalog: true),
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
                  'Engine runtime',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Imported: ${_importedEngines.length}\nEnabled: ${_importedEngines.where((ImportedEngine engine) => engine.enabled).length}\nKeyword-ready: ${_importedEngines.where((ImportedEngine engine) => engine.keywordSearch && engine.supportedInApp).length}\nRemote catalog: ${_catalogEngines.length}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton(
                      onPressed: _importingRecommendedEngines
                          ? null
                          : _importRecommendedEngines,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.text,
                        foregroundColor: AppColors.background,
                      ),
                      child: Text(
                        _importingRecommendedEngines
                            ? 'Importing...'
                            : 'Import recommended',
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _reloadEngineState(refreshCatalog: true),
                      child: const Text('Refresh catalog'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if ((_engineCatalogMessage ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.35)),
              ),
              child: Text(
                _engineCatalogMessage!,
                style:
                    const TextStyle(color: AppColors.textMuted, height: 1.45),
              ),
            ),
          if ((_engineCatalogMessage ?? '').isNotEmpty)
            const SizedBox(height: 12),
          TextField(
            controller: _engineQueryController,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              labelText: 'Keyword search',
              hintText: 'Movie title, show name, release keywords...',
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
            onPressed: _loadingEngineSearch ? null : _searchEngines,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.text,
              foregroundColor: AppColors.background,
            ),
            child:
                Text(_loadingEngineSearch ? 'Searching...' : 'Search engines'),
          ),
          const SizedBox(height: 18),
          const _SectionHeading(
            title: 'Imported engines',
            subtitle:
                'These are the Debrify-style engine configs stored on-device. Toggle them, tune max results, or remove engines you do not want in search.',
          ),
          const SizedBox(height: 12),
          if (_loadingEngineCatalog)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.text),
              ),
            )
          else if (_importedEngines.isEmpty)
            const _SearchEmptyState(
              message:
                  'No engines are imported yet. Start with the recommended set, then search by keyword here just like Debrify\'s engine flow.',
            )
          else
            ..._importedEngines.map(
              (ImportedEngine engine) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EngineCard(
                  engine: engine,
                  onToggle: (bool value) => _toggleEngine(engine, value),
                  onDelete: () => _deleteEngine(engine),
                  onSelectMaxResults: (int value) =>
                      _changeEngineMaxResults(engine, value),
                ),
              ),
            ),
          const SizedBox(height: 6),
          const _SectionHeading(
            title: 'Search diagnostics',
            subtitle:
                'Every imported engine reports its own result count or error, so it is easier to tell whether a provider is empty, unsupported, or broken.',
          ),
          const SizedBox(height: 12),
          _DiagnosticsCard(
            title: 'Engine results',
            counts: _engineCounts,
            errors: _engineErrors,
          ),
          const SizedBox(height: 12),
          if (_availableEngineSources.isNotEmpty) ...<Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _SourceFilterChip(
                    label: 'All (${_engineResults.length})',
                    selected: _selectedEngineSource == null,
                    onTap: () {
                      setState(() {
                        _selectedEngineSource = null;
                      });
                    },
                  ),
                  ..._availableEngineSources.map(
                    (String sourceName) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _SourceFilterChip(
                        label:
                            '$sourceName (${_engineResults.where((StreamSource item) => item.sourceDisplayName == sourceName).length})',
                        selected: _selectedEngineSource == sourceName,
                        onTap: () {
                          setState(() {
                            _selectedEngineSource =
                                _selectedEngineSource == sourceName
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
          if (_loadingEngineSearch)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.text),
              ),
            )
          else if (_engineResults.isEmpty)
            _SearchEmptyState(
              message: _engineMessage ??
                  'Search across your imported torrent engines. Debrify-style engine configs only start contributing here after you import and enable them.',
            )
          else
            ..._visibleEngineResults.map(
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
          const SizedBox(height: 8),
          const _SectionHeading(
            title: 'Remote catalog',
            subtitle:
                'This is the upstream Debrify engine catalog. Import engines from here into the on-device runtime.',
          ),
          const SizedBox(height: 12),
          if (_loadingEngineCatalog)
            const SizedBox.shrink()
          else if (_availableCatalogEngines.isEmpty)
            const _SearchEmptyState(
              message:
                  'All visible catalog engines are already imported on this device.',
            )
          else
            ..._availableCatalogEngines.map(
              (RemoteEngineInfo engine) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CatalogEngineCard(
                  engine: engine,
                  onImport: () => _importEngine(engine),
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

    final bool hasApiKey = (_settings.torBoxApiKey ?? '').trim().isNotEmpty;
    if (!hasApiKey) {
      return const _LibraryEmptyState(
        title: 'Connect TorBox first.',
        message:
            'Open Settings, paste your TorBox API key, and your account library will appear here.',
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
                'Built-in source: Torrentio\nAddons merged: ${_settings.useAddons ? 'Yes' : 'No'}\nInstalled stream addons: ${_addons.where((AddonManifest addon) => addon.enabled && addon.hasStreamResource).length}\nImported keyword engines: ${_importedEngines.where((ImportedEngine engine) => engine.keywordSearch).length}\nEnabled engines: ${_importedEngines.where((ImportedEngine engine) => engine.enabled).length}',
                style: const TextStyle(color: AppColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsJumpCard(
          title: 'Source status',
          subtitle:
              'Check Torrentio health and review how built-in search works.',
          onTap: _openSourceStatus,
        ),
        const SizedBox(height: 12),
        _SettingsJumpCard(
          title: 'Manage addons',
          subtitle:
              'Install Stremio manifests that Torboxers can merge into search.',
          onTap: _openAddons,
        ),
        const SizedBox(height: 12),
        if (_settings.useAddons &&
            _addons
                .where(
                  (AddonManifest addon) =>
                      addon.enabled && addon.hasStreamResource,
                )
                .isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
            ),
            child: const Text(
              'Addons mode is enabled, but no installed addon currently exposes stream resources. Install a configured Torrentio, Comet, MediaFusion, or similar manifest to actually expand search.',
              style: TextStyle(
                color: AppColors.textMuted,
                height: 1.45,
              ),
            ),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
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
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
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

class _EngineCard extends StatelessWidget {
  const _EngineCard({
    required this.engine,
    required this.onToggle,
    required this.onDelete,
    required this.onSelectMaxResults,
  });

  final ImportedEngine engine;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final ValueChanged<int> onSelectMaxResults;

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
                      engine.displayName,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((engine.description ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        engine.description!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: engine.enabled,
                onChanged: onToggle,
                activeColor: AppColors.text,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _HeaderChip(
                  label: engine.keywordSearch ? 'Keyword' : 'No keyword'),
              _HeaderChip(label: engine.imdbSearch ? 'IMDb' : 'No IMDb'),
              _HeaderChip(
                label: engine.supportedInApp
                    ? engine.responseFormat
                    : '${engine.responseFormat} pending',
              ),
              _HeaderChip(label: 'Max ${engine.maxResults}'),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              PopupMenuButton<int>(
                initialValue: engine.maxResults,
                onSelected: onSelectMaxResults,
                itemBuilder: (BuildContext context) {
                  final List<int> options = engine.maxResultOptions.isEmpty
                      ? <int>[25, 50, 100]
                      : engine.maxResultOptions;
                  return options
                      .map(
                        (int option) => PopupMenuItem<int>(
                          value: option,
                          child: Text('Max $option'),
                        ),
                      )
                      .toList(growable: false);
                },
                child: const FilledButton.tonal(
                  onPressed: null,
                  child: Text('Set max results'),
                ),
              ),
              FilledButton.tonal(
                onPressed: onDelete,
                style: FilledButton.styleFrom(
                  foregroundColor: const Color(0xFFFCA5A5),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogEngineCard extends StatelessWidget {
  const _CatalogEngineCard({
    required this.engine,
    required this.onImport,
  });

  final RemoteEngineInfo engine;
  final VoidCallback onImport;

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
          Text(
            engine.displayName,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if ((engine.description ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              engine.description!,
              style: const TextStyle(color: AppColors.textMuted, height: 1.45),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (engine.keywordSearch) const _HeaderChip(label: 'Keyword'),
              if (engine.imdbSearch) const _HeaderChip(label: 'IMDb'),
              if (engine.seriesSupport) const _HeaderChip(label: 'Series'),
              _HeaderChip(
                label: engine.supportedInApp
                    ? engine.responseFormat
                    : '${engine.responseFormat} pending',
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            onPressed: onImport,
            child: const Text('Import'),
          ),
        ],
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
                        if (source.isDirectUrl)
                          const _HeaderChip(label: 'Direct URL'),
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
              Icon(Icons.playlist_add_outlined,
                  color: AppColors.textMuted, size: 36),
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
  const _LibraryEmptyState({
    this.title = 'TorBox library is empty.',
    this.message =
        'Add a source to TorBox from the search tab or the Magnet screen and it will show up here.',
  });

  final String title;
  final String message;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.cloud_off_outlined,
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
                message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textMuted, height: 1.45),
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
                    style: const TextStyle(
                        color: AppColors.textMuted, height: 1.45),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.text : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.background : AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({
    required this.title,
    required this.counts,
    required this.errors,
  });

  final String title;
  final Map<String, int> counts;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    final List<String> orderedSources = <String>{
      ...counts.keys,
      ...errors.keys,
    }.toList()
      ..sort();

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
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (orderedSources.isEmpty)
            const Text(
              'No diagnostics yet.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            ...orderedSources.map(
              (String source) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            source,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            errors[source] == null
                                ? '${counts[source] ?? 0} results'
                                : errors[source]!,
                            style: TextStyle(
                              color: errors[source] == null
                                  ? AppColors.textMuted
                                  : const Color(0xFFFCA5A5),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeaderChip(
                      label: errors[source] == null
                          ? '${counts[source] ?? 0}'
                          : 'Error',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
