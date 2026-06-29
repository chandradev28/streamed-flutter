import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../models/tmdb_media_models.dart';
import '../models/watch_history_item.dart';
import '../services/app_settings_repository.dart';
import '../services/stremio_addons_service.dart';
import '../services/tmdb_image.dart';
import '../services/tmdb_media_service.dart';
import '../services/trakt_api_service.dart';
import '../services/watch_history_repository.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';
import 'addons_screen.dart';
import 'episode_screen.dart';
import 'movie_detail_screen.dart';
import 'profile_screen.dart';
import 'streamed_sources_screen.dart';
import 'video_player_screen.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({
    super.key,
    MediaCatalogService? mediaService,
    ContinueWatchingRepository? watchHistoryRepository,
    AppSettingsRepository? settingsRepository,
    TraktApiService? traktApiService,
    StremioAddonsService? addonsService,
    this.onSettingsChanged,
  })  : mediaService = mediaService ?? TmdbMediaService(),
        watchHistoryRepository =
            watchHistoryRepository ?? WatchHistoryRepository(),
        settingsRepository = settingsRepository ?? AppSettingsRepository(),
        traktApiService = traktApiService ?? TraktApiService(),
        addonsService = addonsService ?? StremioAddonsService();

  final MediaCatalogService mediaService;
  final ContinueWatchingRepository watchHistoryRepository;
  final AppSettingsRepository settingsRepository;
  final TraktApiService traktApiService;
  final StremioAddonsService addonsService;
  final Future<void> Function()? onSettingsChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _heroController = PageController();
  List<WatchHistoryItem> _continueWatching = const <WatchHistoryItem>[];
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  int _heroIndex = 0;
  List<AddonCatalogRow> _catalogRows = const <AddonCatalogRow>[];
  List<AddonManifest> _installedAddons = const <AddonManifest>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadHome();
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
    });

    try {
      final List<dynamic> results =
          await Future.wait<dynamic>(<Future<dynamic>>[
        _loadSettingsOrKeep(),
        _loadOrKeep<WatchHistoryItem>(
          _continueWatching,
          () => widget.watchHistoryRepository.getContinueWatching(20),
        ),
        _loadInstalledAddonsOrKeep(),
        _loadCatalogRowsOrKeep(),
      ]);

      if (!mounted) {
        return;
      }

      final AppSettings settings = results[0] as AppSettings;
      setState(() {
        _settings = settings;
        _continueWatching = _sortContinueWatching(
          results[1] as List<WatchHistoryItem>,
          settings,
        );
        _installedAddons = results[2] as List<AddonManifest>;
        _catalogRows = results[3] as List<AddonCatalogRow>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _catalogRows = const <AddonCatalogRow>[];
      });
    }
  }

  Future<AppSettings> _loadSettingsOrKeep() async {
    try {
      return await widget.settingsRepository.loadSettings();
    } catch (_) {
      return _settings;
    }
  }

  Future<List<AddonManifest>> _loadInstalledAddonsOrKeep() async {
    try {
      return await widget.addonsService.getInstalledAddons();
    } catch (_) {
      return _installedAddons;
    }
  }

  Future<List<AddonCatalogRow>> _loadCatalogRowsOrKeep() async {
    try {
      return await widget.addonsService.fetchAllCatalogRows();
    } catch (_) {
      return _catalogRows;
    }
  }

  Future<List<T>> _loadOrKeep<T>(
    List<T> current,
    Future<List<T>> Function() loader,
  ) async {
    try {
      final List<T> items = await loader();
      return items.isEmpty && current.isNotEmpty ? current : items;
    } catch (_) {
      return current;
    }
  }

  void _openCatalogItem(AddonCatalogItem item) {
    final String imdbId = item.id.startsWith('tt') ? item.id : '';

    if (imdbId.isNotEmpty) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => StreamedSourcesScreen(
            title: item.name,
            posterPath: null,
            mediaType: item.mediaType,
            imdbId: imdbId,
            tmdbId: int.tryParse(
                RegExp(r'^tmdb:(\d+)').firstMatch(item.id)?.group(1) ?? ''),
          ),
        ),
      );
      return;
    }

    final String? tmdbStr =
        RegExp(r'^tmdb:(\d+)').firstMatch(item.id)?.group(1);
    if (tmdbStr != null) {
      final int? tmdbId = int.tryParse(tmdbStr);
      if (tmdbId != null) {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => MovieDetailScreen(
              id: tmdbId,
              mediaType: item.mediaType,
            ),
          ),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot open this catalog item yet.')),
    );
  }

  Future<void> _openContinueWatching(WatchHistoryItem item) async {
    final bool resumePlayback = await _shouldResumePlayback(item);
    if (!mounted) {
      return;
    }

    if (_hasPlayableHistoryContext(item)) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => VideoPlayerScreen(
            title: item.title,
            posterUrl: item.posterPath ?? item.backdropPath,
            tmdbId: item.tmdbId,
            imdbId: item.imdbId,
            mediaType: item.mediaType,
            seasonNumber: item.seasonNumber,
            episodeNumber: item.episodeNumber,
            episodeName: item.episodeName,
            torrentHash: item.torrentHash,
            torrentId: item.torrentId,
            initialVideoUrl: item.resolvedUrl,
            initialFileId: item.activeFileId,
            initialFileIndex: item.activeFileIndex,
            initialFileName: item.activeFileName,
            startPositionMs: resumePlayback ? item.currentTime : 0,
            provider: item.provider,
            streamHeaders: item.streamHeaders ?? const <String, String>{},
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      await _loadHome();
      return;
    }

    await _openContinueWatchingFallback(item);
  }

  bool _hasPlayableHistoryContext(WatchHistoryItem item) {
    return (item.resolvedUrl ?? '').isNotEmpty || item.torrentId != null;
  }

  Future<bool> _shouldResumePlayback(WatchHistoryItem item) async {
    if (!_settings.continueWatchingResumePrompt ||
        item.currentTime <= 0 ||
        item.duration <= 0) {
      return true;
    }

    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Resume from ${_formatWatchTime(item.currentTime)} or start again from the beginning.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: LayoutOptions.accentFor(_settings),
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child:
                        Text('Resume at ${_formatWatchTime(item.currentTime)}'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: BorderSide(color: Colors.white.withOpacity(0.14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Start over'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? true;
  }

  Future<void> _openContinueWatchingFallback(WatchHistoryItem item) async {
    try {
      final MediaDetail detail =
          await widget.mediaService.getMediaDetail(item.tmdbId, item.mediaType);
      if (!mounted) {
        return;
      }

      final String? imdbId = detail.imdbId;
      if ((imdbId ?? '').isNotEmpty) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => StreamedSourcesScreen(
              title: detail.title,
              posterPath: item.posterPath ?? detail.posterPath,
              mediaType: item.mediaType,
              imdbId: imdbId!,
              tmdbId: item.tmdbId,
              seasonNumber: item.seasonNumber,
              episodeNumber: item.episodeNumber,
              episodeName: item.episodeName,
            ),
          ),
        );
      } else if (item.mediaType == 'tv' && item.seasonNumber != null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => EpisodeScreen(
              tvId: item.tmdbId,
              initialSeason: item.seasonNumber ?? 1,
              showName: detail.title,
              posterPath: item.posterPath ?? detail.posterPath,
              mediaService: widget.mediaService,
            ),
          ),
        );
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => MovieDetailScreen(
              id: item.tmdbId,
              mediaType: item.mediaType,
              mediaService: widget.mediaService,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not reopen this Continue Watching item yet.'),
        ),
      );
    }

    if (!mounted) {
      return;
    }
    await _loadHome();
  }

  Future<void> _removeHistory(String id) async {
    await widget.watchHistoryRepository.removeFromHistory(id);
    if (!mounted) {
      return;
    }

    setState(() {
      _continueWatching = _continueWatching
          .where((WatchHistoryItem item) => item.id != id)
          .toList(growable: false);
    });
  }

  void _openProfile() {
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ProfileScreen(),
      ),
    )
        .then((_) async {
      await _loadHome();
      await widget.onSettingsChanged?.call();
    });
  }

  Future<void> _openAddons() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AddonsScreen(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadHome();
  }

  List<WatchHistoryItem> _sortContinueWatching(
    List<WatchHistoryItem> items, [
    AppSettings? settings,
  ]) {
    final AppSettings activeSettings = settings ?? _settings;
    final List<WatchHistoryItem> sorted = items.toList(growable: false);
    if (activeSettings.continueWatchingSortOrder == 'streaming') {
      sorted.sort((WatchHistoryItem a, WatchHistoryItem b) {
        final int type = _streamingWeight(a).compareTo(_streamingWeight(b));
        if (type != 0) {
          return type;
        }
        return b.lastWatched.compareTo(a.lastWatched);
      });
      return sorted;
    }

    sorted.sort((WatchHistoryItem a, WatchHistoryItem b) {
      return b.lastWatched.compareTo(a.lastWatched);
    });
    return sorted;
  }

  int _streamingWeight(WatchHistoryItem item) {
    if (item.mediaType == 'tv') {
      return 0;
    }
    if (item.mediaType == 'movie') {
      return 1;
    }
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = LayoutOptions.accentFor(_settings);
    final AddonCatalogRow? heroRow =
        _catalogRows.isEmpty ? null : _catalogRows.first;
    final List<AddonCatalogItem> heroItems = heroRow == null
        ? const <AddonCatalogItem>[]
        : heroRow.items.take(8).toList();
    final bool hasEnabledCatalogAddon = _installedAddons.any(
      (AddonManifest addon) => addon.enabled && addon.catalogs.isNotEmpty,
    );

    return Scaffold(
      backgroundColor: LayoutOptions.backgroundFor(_settings),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHome,
          color: accent,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  'Streamed',
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Powered by your Stremio addons',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _SquareHeaderButton(
                            key: const ValueKey<String>(
                              'home-profile-button',
                            ),
                            icon: Icons.person_outline_rounded,
                            onTap: _openProfile,
                          ),
                        ],
                      ),
                      if ((_settings.traktAccessToken ?? '').isNotEmpty &&
                          _settings.traktSyncProgressEnabled) ...<Widget>[
                        const SizedBox(height: 14),
                        _TraktSyncCard(
                          username: _settings.traktUsername,
                          accent: accent,
                          onTap: _openProfile,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_loading && _catalogRows.isEmpty)
                const SliverToBoxAdapter(child: _HeroSkeleton())
              else if (_catalogRows.isEmpty)
                SliverToBoxAdapter(
                  child: _AddonHomeEmptyState(
                    hasInstalledAddons: _installedAddons.isNotEmpty,
                    hasEnabledCatalogAddon: hasEnabledCatalogAddon,
                    accent: accent,
                    onOpenAddons: _openAddons,
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: _AddonHeroCarousel(
                    controller: _heroController,
                    items: heroItems,
                    addon: heroRow!.addon,
                    activeIndex: _heroIndex,
                    accent: accent,
                    addonsService: widget.addonsService,
                    onPageChanged: (int index) {
                      setState(() {
                        _heroIndex = index;
                      });
                    },
                    onOpen: _openCatalogItem,
                  ),
                ),
              if (_settings.continueWatchingEnabled &&
                  _continueWatching.isNotEmpty) ...<Widget>[
                _SectionHeader(title: 'Continue Watching', accent: accent),
                SliverToBoxAdapter(
                  child: _ContinueWatchingRail(
                    items: _continueWatching,
                    settings: _settings,
                    accent: accent,
                    onOpen: _openContinueWatching,
                    onRemove: _removeHistory,
                  ),
                ),
              ],
              if (_catalogRows.isNotEmpty) ...<Widget>[
                for (final AddonCatalogRow row in _catalogRows) ...[
                  _SectionHeader(
                    title: row.catalogName,
                    actionLabel: row.addonName,
                    accent: accent,
                  ),
                  SliverToBoxAdapter(
                    child: _CatalogRail(
                      items: row.items,
                      addon: row.addon,
                      addonsService: widget.addonsService,
                      settings: _settings,
                      onOpen: (AddonCatalogItem item) => _openCatalogItem(item),
                    ),
                  ),
                ],
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 92)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TraktSyncCard extends StatelessWidget {
  const _TraktSyncCard({
    required this.username,
    required this.accent,
    required this.onTap,
  });

  final String? username;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.alphaBlend(
        accent.withOpacity(0.10),
        AppColors.cardBackground,
      ),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.checklist_rtl_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Trakt sync active',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (username ?? '').isEmpty
                          ? 'Scrobbling and progress sync are enabled.'
                          : 'Signed in as $username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareHeaderButton extends StatelessWidget {
  const _SquareHeaderButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          color: const Color(0xD9121217),
        ),
        child: Icon(icon, color: AppColors.text, size: 20),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.height,
    required this.borderRadius,
  });

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 2, 16, 22),
      child: _SkeletonBlock(
        height: 430,
        borderRadius: 34,
      ),
    );
  }
}

class _AddonHomeEmptyState extends StatelessWidget {
  const _AddonHomeEmptyState({
    required this.hasInstalledAddons,
    required this.hasEnabledCatalogAddon,
    required this.accent,
    required this.onOpenAddons,
  });

  final bool hasInstalledAddons;
  final bool hasEnabledCatalogAddon;
  final Color accent;
  final VoidCallback onOpenAddons;

  @override
  Widget build(BuildContext context) {
    final String title = !hasInstalledAddons
        ? 'Add your first catalog addon'
        : hasEnabledCatalogAddon
            ? 'No catalog posters yet'
            : 'Enable a catalog addon';
    final String body = !hasInstalledAddons
        ? 'Install AIOStreams, Cinemeta, MediaFusion, or another Stremio addon with catalogs. Home stays clean until addons provide posters.'
        : hasEnabledCatalogAddon
            ? 'Your enabled addons did not return catalog items yet. Refresh them or add a metadata/catalog addon.'
            : 'Installed addons exist, but none with catalogs are enabled. Turn one on to build your Home shelves.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accent.withOpacity(0.16),
              AppColors.cardBackground,
              Colors.white.withOpacity(0.03),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.grid_view_rounded, color: accent, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 28,
                height: 1.0,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onOpenAddons,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.text,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: const Icon(Icons.extension_rounded, size: 18),
              label: const Text(
                'Manage addons',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddonHeroCarousel extends StatelessWidget {
  const _AddonHeroCarousel({
    required this.controller,
    required this.items,
    required this.addon,
    required this.activeIndex,
    required this.accent,
    required this.addonsService,
    required this.onPageChanged,
    required this.onOpen,
  });

  final PageController controller;
  final List<AddonCatalogItem> items;
  final AddonManifest addon;
  final int activeIndex;
  final Color accent;
  final StremioAddonsService addonsService;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<AddonCatalogItem> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(height: 24);
    }

    return SizedBox(
      height: 438,
      child: Stack(
        children: <Widget>[
          PageView.builder(
            controller: controller,
            itemCount: items.length,
            onPageChanged: onPageChanged,
            itemBuilder: (BuildContext context, int index) {
              final AddonCatalogItem item = items[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
                child: _AddonHeroPanel(
                  item: item,
                  addon: addon,
                  accent: accent,
                  addonsService: addonsService,
                  onTap: () => onOpen(item),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                items.length,
                (int index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: activeIndex == index ? 34 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: activeIndex == index
                        ? accent
                        : Colors.white.withOpacity(0.58),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddonHeroPanel extends StatelessWidget {
  const _AddonHeroPanel({
    required this.item,
    required this.addon,
    required this.accent,
    required this.addonsService,
    required this.onTap,
  });

  final AddonCatalogItem item;
  final AddonManifest addon;
  final Color accent;
  final StremioAddonsService addonsService;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = addonsService.resolveAddonUrl(
      addon,
      item.background ?? item.poster,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(34),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.40),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (imageUrl.isEmpty)
            const ColoredBox(color: AppColors.cardBackground)
          else
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return const ColoredBox(color: AppColors.cardBackground);
              },
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withOpacity(0.08),
                  Colors.black.withOpacity(0.42),
                  Colors.black.withOpacity(0.94),
                ],
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 24,
            child: Column(
              children: <Widget>[
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 32,
                    height: 0.98,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: <Widget>[
                    _HeroMeta(
                      label: item.mediaType == 'tv' ? 'Series' : 'Movie',
                    ),
                    if ((item.releaseInfo ?? '').isNotEmpty)
                      _HeroMeta(label: item.releaseInfo!),
                    _HeroMeta(label: addon.name),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.text,
                    foregroundColor: AppColors.background,
                    shadowColor: accent.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 34,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Open sources',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.accent,
    this.actionLabel,
  });

  final String title;
  final Color accent;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Row(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 64,
                  height: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (actionLabel != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Text(
                  actionLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContinueWatchingRail extends StatelessWidget {
  const _ContinueWatchingRail({
    required this.items,
    required this.settings,
    required this.accent,
    required this.onOpen,
    required this.onRemove,
  });

  final List<WatchHistoryItem> items;
  final AppSettings settings;
  final Color accent;
  final ValueChanged<WatchHistoryItem> onOpen;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final bool posterStyle = settings.continueWatchingStyle == 'poster';
    return SizedBox(
      height: posterStyle ? 194 : 166,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 24, 0),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final WatchHistoryItem item = items[index];
          if (posterStyle) {
            return _PosterContinueCard(
              item: item,
              accent: accent,
              blur: settings.continueWatchingBlurUnwatched,
              onOpen: () => onOpen(item),
              onRemove: () => onRemove(item.id),
            );
          }

          if (index == 0) {
            return _GlanceContinueCard(
              item: item,
              accent: accent,
              blur: settings.continueWatchingBlurUnwatched,
              onOpen: () => onOpen(item),
              onRemove: () => onRemove(item.id),
            );
          }

          return _MiniContinueCard(
            item: item,
            accent: accent,
            blur: settings.continueWatchingBlurUnwatched,
            onOpen: () => onOpen(item),
            onRemove: () => onRemove(item.id),
          );
        },
      ),
    );
  }
}

class _GlanceContinueCard extends StatelessWidget {
  const _GlanceContinueCard({
    required this.item,
    required this.accent,
    required this.blur,
    required this.onOpen,
    required this.onRemove,
  });

  final WatchHistoryItem item;
  final Color accent;
  final bool blur;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: onOpen,
          child: Container(
            width: 330,
            height: 150,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Colors.white.withOpacity(0.07),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 102,
                      height: double.infinity,
                      child: _HistoryArtwork(item: item, blur: blur),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 17,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    _subtitle(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Resume',
                                    style: TextStyle(
                                      color: AppColors.background,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _timeLeft(item),
                              style: const TextStyle(
                                color: AppColors.textSubtle,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                minHeight: 4,
                                value: (item.progress / 100).clamp(0, 1),
                                color: accent,
                                backgroundColor: Colors.white.withOpacity(0.14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: _RemovePill(onTap: onRemove),
        ),
      ],
    );
  }
}

class _MiniContinueCard extends StatelessWidget {
  const _MiniContinueCard({
    required this.item,
    required this.accent,
    required this.blur,
    required this.onOpen,
    required this.onRemove,
  });

  final WatchHistoryItem item;
  final Color accent;
  final bool blur;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: onOpen,
          child: Container(
            width: 110,
            height: 142,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _HistoryArtwork(item: item, blur: blur),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: (item.progress / 100).clamp(0, 1),
                    color: accent,
                    backgroundColor: Colors.black.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: _RemovePill(onTap: onRemove, compact: true),
        ),
      ],
    );
  }
}

class _PosterContinueCard extends StatelessWidget {
  const _PosterContinueCard({
    required this.item,
    required this.accent,
    required this.blur,
    required this.onOpen,
    required this.onRemove,
  });

  final WatchHistoryItem item;
  final Color accent;
  final bool blur;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: onOpen,
          child: Container(
            width: 124,
            height: 182,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _HistoryArtwork(item: item, blur: blur),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.black.withOpacity(0.78),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 13,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: (item.progress / 100).clamp(0, 1),
                          color: accent,
                          backgroundColor: Colors.white.withOpacity(0.18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: _RemovePill(onTap: onRemove, compact: true),
        ),
      ],
    );
  }
}

class _HistoryArtwork extends StatelessWidget {
  const _HistoryArtwork({
    required this.item,
    required this.blur,
  });

  final WatchHistoryItem item;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final String? imagePath = item.posterPath ?? item.backdropPath;
    Widget child = imagePath == null
        ? const ColoredBox(color: AppColors.cardBackground)
        : Image.network(
            getImageUrl(imagePath, 'w342'),
            fit: BoxFit.cover,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return const ColoredBox(color: AppColors.cardBackground);
            },
          );
    if (blur) {
      child = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: child,
      );
    }
    return child;
  }
}

class _RemovePill extends StatelessWidget {
  const _RemovePill({
    required this.onTap,
    this.compact = false,
  });

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: compact ? 22 : 26,
        height: compact ? 22 : 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.7),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: const Icon(Icons.close, size: 14, color: AppColors.text),
      ),
    );
  }
}

String _subtitle(WatchHistoryItem item) {
  if (item.mediaType == 'tv' &&
      item.seasonNumber != null &&
      item.episodeNumber != null) {
    return 'S${item.seasonNumber}E${item.episodeNumber}';
  }

  return item.mediaType == 'movie' ? 'Movie' : 'TV Show';
}

String _timeLeft(WatchHistoryItem item) {
  final int remainingMs = (item.duration - item.currentTime).clamp(
    0,
    item.duration > 0 ? item.duration : 0,
  );
  if (remainingMs <= 0) {
    return 'Ready to finish';
  }

  final int remainingMinutes =
      (Duration(milliseconds: remainingMs).inSeconds / 60).ceil();
  if (remainingMinutes < 60) {
    return '$remainingMinutes min left';
  }

  final int hours = remainingMinutes ~/ 60;
  final int minutes = remainingMinutes % 60;
  return '${hours}h ${minutes}m left';
}

String _formatWatchTime(int milliseconds) {
  final Duration duration =
      Duration(milliseconds: milliseconds.clamp(0, milliseconds));
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${duration.inMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class _CatalogRail extends StatelessWidget {
  const _CatalogRail({
    required this.items,
    required this.addon,
    required this.addonsService,
    required this.settings,
    required this.onOpen,
  });

  final List<AddonCatalogItem> items;
  final AddonManifest addon;
  final StremioAddonsService addonsService;
  final AppSettings settings;
  final ValueChanged<AddonCatalogItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final double posterWidth = LayoutOptions.posterWidth(settings);
    final double posterHeight = settings.posterLandscapeEnabled
        ? posterWidth * 0.62
        : posterWidth * 1.45;
    final double cardHeight =
        settings.posterHideLabels ? posterHeight + 12 : posterHeight + 42;
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (BuildContext context, int index) {
          final AddonCatalogItem item = items[index];
          return _CatalogPosterCard(
            item: item,
            posterUrl: addonsService.resolveAddonUrl(
              addon,
              settings.posterLandscapeEnabled
                  ? (item.background ?? item.poster)
                  : item.poster,
            ),
            width: posterWidth,
            height: posterHeight,
            radius: LayoutOptions.posterRadius(settings),
            hideLabel: settings.posterHideLabels,
            onTap: () => onOpen(item),
          );
        },
      ),
    );
  }
}

class _CatalogPosterCard extends StatelessWidget {
  const _CatalogPosterCard({
    required this.item,
    required this.posterUrl,
    required this.width,
    required this.height,
    required this.radius,
    required this.hideLabel,
    required this.onTap,
  });

  final AddonCatalogItem item;
  final String posterUrl;
  final double width;
  final double height;
  final double radius;
  final bool hideLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: posterUrl.isEmpty
                  ? const ColoredBox(color: AppColors.cardBackground)
                  : Image.network(
                      posterUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const ColoredBox(
                          color: AppColors.cardBackground,
                        );
                      },
                    ),
            ),
            if (!hideLabel) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
