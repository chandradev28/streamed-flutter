import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../models/tmdb_media_models.dart';
import '../models/watch_history_item.dart';
import '../services/app_settings_repository.dart';
import '../services/tmdb_image.dart';
import '../services/tmdb_media_service.dart';
import '../services/watch_history_repository.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';
import 'episode_screen.dart';
import 'movie_detail_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({
    super.key,
    MediaCatalogService? mediaService,
    ContinueWatchingRepository? watchHistoryRepository,
    AppSettingsRepository? settingsRepository,
    this.onSettingsChanged,
  })  : mediaService = mediaService ?? TmdbMediaService(),
        watchHistoryRepository =
            watchHistoryRepository ?? WatchHistoryRepository(),
        settingsRepository = settingsRepository ?? AppSettingsRepository();

  final MediaCatalogService mediaService;
  final ContinueWatchingRepository watchHistoryRepository;
  final AppSettingsRepository settingsRepository;
  final Future<void> Function()? onSettingsChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _heroController = PageController();
  List<MediaSummary> _trending = const <MediaSummary>[];
  List<MediaSummary> _trendingSeries = const <MediaSummary>[];
  List<MediaSummary> _newReleases = const <MediaSummary>[];
  List<WatchHistoryItem> _continueWatching = const <WatchHistoryItem>[];
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  int _heroIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadHome();
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

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      widget.settingsRepository.loadSettings(),
      _loadOrKeep<MediaSummary>(
        _trending,
        widget.mediaService.getTrendingMovies,
      ),
      _loadOrKeep<MediaSummary>(
        _trendingSeries,
        widget.mediaService.getTrendingSeries,
      ),
      _loadOrKeep<MediaSummary>(
        _newReleases,
        widget.mediaService.getNowPlayingMovies,
      ),
      _loadOrKeep<WatchHistoryItem>(
        _continueWatching,
        () => widget.watchHistoryRepository.getContinueWatching(20),
      ),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = results[0] as AppSettings;
      _trending = results[1] as List<MediaSummary>;
      _trendingSeries = results[2] as List<MediaSummary>;
      _newReleases = results[3] as List<MediaSummary>;
      _continueWatching = _sortContinueWatching(
        results[4] as List<WatchHistoryItem>,
      );
      _loading = false;
    });
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

  void _openMedia(MediaSummary item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MovieDetailScreen(
          id: item.id,
          mediaType: item.mediaType,
          mediaService: widget.mediaService,
        ),
      ),
    );
  }

  void _openContinueWatching(WatchHistoryItem item) {
    if (item.mediaType == 'tv' && item.seasonNumber != null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => EpisodeScreen(
            tvId: item.tmdbId,
            initialSeason: item.seasonNumber ?? 1,
            showName: item.title,
            posterPath: item.posterPath,
            mediaService: widget.mediaService,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MovieDetailScreen(
          id: item.tmdbId,
          mediaType: item.mediaType,
          mediaService: widget.mediaService,
        ),
      ),
    );
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

  List<WatchHistoryItem> _sortContinueWatching(List<WatchHistoryItem> items) {
    final List<WatchHistoryItem> sorted = items.toList(growable: false);
    if (_settings.continueWatchingSortOrder == 'streaming') {
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
    final List<MediaSummary> heroItems = <MediaSummary>[
      ..._trending.take(4),
      ..._trendingSeries.take(4),
    ];
    final Color accent = LayoutOptions.accentFor(_settings);

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
                                  'Movies, shows, and TorBox tools',
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
                      if (_loading) ...<Widget>[
                        const SizedBox(height: 14),
                        const _TorBoxSetupPrompt(),
                      ],
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _loading && heroItems.isEmpty
                    ? const _HeroSkeleton()
                    : _HomeHeroCarousel(
                        controller: _heroController,
                        items: heroItems,
                        activeIndex: _heroIndex,
                        accent: accent,
                        onPageChanged: (int index) {
                          setState(() {
                            _heroIndex = index;
                          });
                        },
                        onOpen: _openMedia,
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
              _SectionHeader(
                title: 'Top 10 Movies This Week',
                actionLabel: 'View All',
                accent: accent,
              ),
              SliverToBoxAdapter(
                child: _loading && _trending.isEmpty
                    ? const _PosterSkeletonRow(
                        height: 250,
                        itemWidth: 138,
                        itemHeight: 204,
                        count: 4,
                      )
                    : _TopTenRail(
                        items: _trending,
                        settings: _settings,
                        accent: accent,
                        onOpen: _openMedia,
                      ),
              ),
              _SectionHeader(
                title: 'Top 10 Series This Week',
                actionLabel: 'View All',
                accent: accent,
              ),
              SliverToBoxAdapter(
                child: _loading && _trendingSeries.isEmpty
                    ? const _PosterSkeletonRow(
                        height: 250,
                        itemWidth: 138,
                        itemHeight: 204,
                        count: 4,
                      )
                    : _TopTenRail(
                        items: _trendingSeries,
                        settings: _settings,
                        accent: accent,
                        onOpen: _openMedia,
                      ),
              ),
              _SectionHeader(title: 'New Releases', accent: accent),
              SliverToBoxAdapter(
                child: _loading && _newReleases.isEmpty
                    ? const _PosterSkeletonRow(
                        height: 235,
                        itemWidth: 155,
                        itemHeight: 185,
                        count: 4,
                      )
                    : SizedBox(
                        height: _settings.posterLandscapeEnabled ? 164 : 235,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                          scrollDirection: Axis.horizontal,
                          itemCount: _newReleases.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (BuildContext context, int index) {
                            final MediaSummary item = _newReleases[index];
                            return _NewReleaseCard(
                              item: item,
                              settings: _settings,
                              onTap: () => _openMedia(item),
                            );
                          },
                        ),
                      ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 132)),
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

class _TorBoxSetupPrompt extends StatelessWidget {
  const _TorBoxSetupPrompt();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.key_rounded,
              color: AppColors.text,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Set up TorBox anytime',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Use the profile button while movies load.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_upward_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _PosterSkeletonRow extends StatelessWidget {
  const _PosterSkeletonRow({
    required this.height,
    required this.itemWidth,
    required this.itemHeight,
    required this.count,
  });

  final double height;
  final double itemWidth;
  final double itemHeight;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (BuildContext context, int index) {
          return SizedBox(
            width: itemWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SkeletonBlock(
                  height: itemHeight,
                  borderRadius: 16,
                ),
                const SizedBox(height: 10),
                const _SkeletonBlock(
                  height: 12,
                  borderRadius: 999,
                ),
              ],
            ),
          );
        },
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

class _HomeHeroCarousel extends StatelessWidget {
  const _HomeHeroCarousel({
    required this.controller,
    required this.items,
    required this.activeIndex,
    required this.accent,
    required this.onPageChanged,
    required this.onOpen,
  });

  final PageController controller;
  final List<MediaSummary> items;
  final int activeIndex;
  final Color accent;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<MediaSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(height: 24);
    }

    return SizedBox(
      height: 460,
      child: Stack(
        children: <Widget>[
          PageView.builder(
            controller: controller,
            itemCount: items.length,
            onPageChanged: onPageChanged,
            itemBuilder: (BuildContext context, int index) {
              final MediaSummary item = items[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
                child: _HeroPanel(
                  item: item,
                  accent: accent,
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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.item,
    required this.accent,
    required this.onTap,
  });

  final MediaSummary item;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? imagePath = item.backdropPath ?? item.posterPath;
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
          if (imagePath == null)
            const ColoredBox(color: AppColors.cardBackground)
          else
            Image.network(
              getImageUrl(imagePath, 'w780'),
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
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.45),
                  Colors.black.withOpacity(0.92),
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
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 34,
                    height: 0.98,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: <Widget>[
                    _HeroMeta(
                        label: item.mediaType == 'tv' ? 'Series' : 'Movie'),
                    _HeroMeta(label: _year(item.releaseDate)),
                    const _HeroMeta(label: 'Top 10 this week'),
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
                    'View Details',
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

class _TopTenRail extends StatelessWidget {
  const _TopTenRail({
    required this.items,
    required this.settings,
    required this.accent,
    required this.onOpen,
  });

  final List<MediaSummary> items;
  final AppSettings settings;
  final Color accent;
  final ValueChanged<MediaSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final double cardWidth = LayoutOptions.posterWidth(settings) + 18;
    final double cardHeight = settings.posterLandscapeEnabled
        ? (LayoutOptions.posterWidth(settings) * 0.66) + 54
        : (LayoutOptions.posterWidth(settings) * 1.48) + 54;
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (BuildContext context, int index) {
          final MediaSummary item = items[index];
          return _RankedPosterCard(
            rank: index + 1,
            item: item,
            width: cardWidth,
            posterWidth: LayoutOptions.posterWidth(settings),
            radius: LayoutOptions.posterRadius(settings),
            landscape: settings.posterLandscapeEnabled,
            hideLabel: settings.posterHideLabels,
            accent: accent,
            onTap: () => onOpen(item),
          );
        },
      ),
    );
  }
}

class _RankedPosterCard extends StatelessWidget {
  const _RankedPosterCard({
    required this.rank,
    required this.item,
    required this.width,
    required this.posterWidth,
    required this.radius,
    required this.landscape,
    required this.hideLabel,
    required this.accent,
    required this.onTap,
  });

  final int rank;
  final MediaSummary item;
  final double width;
  final double posterWidth;
  final double radius;
  final bool landscape;
  final bool hideLabel;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? imagePath = landscape
        ? (item.backdropPath ?? item.posterPath)
        : (item.posterPath ?? item.backdropPath);
    final double posterHeight =
        landscape ? posterWidth * 0.66 : posterWidth * 1.48;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: 18,
              top: 0,
              width: posterWidth,
              height: posterHeight,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: imagePath == null
                    ? const ColoredBox(color: AppColors.cardBackground)
                    : Image.network(
                        getImageUrl(imagePath, landscape ? 'w780' : 'w342'),
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
            ),
            Positioned(
              left: 0,
              top: posterHeight - 72,
              child: Text(
                rank.toString(),
                style: TextStyle(
                  color: accent.withOpacity(0.38),
                  fontSize: 78,
                  height: 0.8,
                  fontWeight: FontWeight.w900,
                  shadows: const <Shadow>[
                    Shadow(color: Colors.white, blurRadius: 1.2),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 28,
              right: 8,
              top: posterHeight - 24,
              child: hideLabel
                  ? const SizedBox.shrink()
                  : Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        shadows: <Shadow>[
                          Shadow(color: Colors.black, blurRadius: 8),
                        ],
                      ),
                    ),
            ),
          ],
        ),
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
                child: Row(
                  children: <Widget>[
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.text,
                      size: 16,
                    ),
                  ],
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
      height: posterStyle ? 190 : 154,
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
            width: 304,
            height: 142,
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
                      width: 92,
                      height: double.infinity,
                      child: _HistoryArtwork(item: item, blur: blur),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
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
                                ),
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
                                    'Up next',
                                    style: TextStyle(
                                      color: AppColors.background,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _subtitle(item),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _timeLeft(item),
                              style: const TextStyle(
                                color: AppColors.textSubtle,
                                fontSize: 12,
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
          top: 8,
          right: 8,
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

class _NewReleaseCard extends StatelessWidget {
  const _NewReleaseCard({
    required this.item,
    required this.settings,
    required this.onTap,
  });

  final MediaSummary item;
  final AppSettings settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double width = LayoutOptions.posterWidth(settings) + 18;
    final double height = settings.posterLandscapeEnabled ? 150 : 225;
    final String? imagePath = settings.posterLandscapeEnabled
        ? (item.backdropPath ?? item.posterPath)
        : (item.posterPath ?? item.backdropPath);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius:
              BorderRadius.circular(LayoutOptions.posterRadius(settings)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            imagePath == null
                ? const ColoredBox(color: AppColors.cardBackground)
                : Image.network(
                    getImageUrl(
                      imagePath,
                      settings.posterLandscapeEnabled ? 'w780' : 'w342',
                    ),
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
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
            if (!settings.posterHideLabels)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _year(item.releaseDate),
                      style: const TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
  final int remainingSeconds = item.duration - item.currentTime;
  final int remainingMinutes = (remainingSeconds / 60).ceil();
  if (remainingMinutes < 60) {
    return '$remainingMinutes min left';
  }

  final int hours = remainingMinutes ~/ 60;
  final int minutes = remainingMinutes % 60;
  return '${hours}h ${minutes}m left';
}

String _year(String date) => date.isEmpty ? '' : date.split('-').first;
