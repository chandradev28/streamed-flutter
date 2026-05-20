import 'package:flutter/material.dart';

import '../models/tmdb_media_models.dart';
import '../models/watch_history_item.dart';
import '../services/tmdb_image.dart';
import '../services/tmdb_media_service.dart';
import '../services/watch_history_repository.dart';
import '../theme/app_colors.dart';
import 'episode_screen.dart';
import 'movie_detail_screen.dart';
import 'profile_screen.dart';
import 'torboxers_screen.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({
    super.key,
    this.mediaService = const TmdbMediaService(),
    ContinueWatchingRepository? watchHistoryRepository,
  }) : watchHistoryRepository =
            watchHistoryRepository ?? WatchHistoryRepository();

  final MediaCatalogService mediaService;
  final ContinueWatchingRepository watchHistoryRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MediaSummary> _trending = const <MediaSummary>[];
  List<MediaSummary> _newReleases = const <MediaSummary>[];
  List<WatchHistoryItem> _continueWatching = const <WatchHistoryItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
    });

    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.mediaService.getTrendingMovies(),
        widget.mediaService.getNowPlayingMovies(),
        widget.watchHistoryRepository.getContinueWatching(20),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _trending = results[0] as List<MediaSummary>;
        _newReleases = results[1] as List<MediaSummary>;
        _continueWatching = results[2] as List<WatchHistoryItem>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
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

  void _openTorboxers() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TorboxersScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHome,
          color: AppColors.text,
          backgroundColor: AppColors.surface,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.text),
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Streamed',
                                        style: TextStyle(
                                          color: AppColors.text,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Browse titles, jump into Torboxers, and keep playback moving.',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _SquareHeaderButton(
                                  icon: Icons.person_outline,
                                  onTap: () {
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (BuildContext context) =>
                                            ProfileScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _TorboxersHeroCard(onTap: _openTorboxers),
                          ],
                        ),
                      ),
                    ),
                    const _SectionHeader(title: 'Top trending movies'),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 282,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 0, 8, 0),
                          scrollDirection: Axis.horizontal,
                          itemCount: _trending.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 16),
                          itemBuilder: (BuildContext context, int index) {
                            final MediaSummary item = _trending[index];
                            return _PosterWithLabel(
                              title: item.title,
                              imagePath: item.posterPath,
                              width: 160,
                              height: 240,
                              onTap: () => _openMedia(item),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_continueWatching.isNotEmpty) ...<Widget>[
                      const _SectionHeader(title: 'Continue Watching'),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 170,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: _continueWatching.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (BuildContext context, int index) {
                              final WatchHistoryItem item =
                                  _continueWatching[index];
                              if (index == 0) {
                                return _FeaturedContinueCard(
                                  item: item,
                                  onOpen: () => _openContinueWatching(item),
                                  onRemove: () => _removeHistory(item.id),
                                );
                              }

                              return _MiniContinueCard(
                                item: item,
                                onOpen: () => _openContinueWatching(item),
                                onRemove: () => _removeHistory(item.id),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    const _SectionHeader(title: 'New Releases'),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 235,
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
                              onTap: () => _openMedia(item),
                            );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SquareHeaderButton extends StatelessWidget {
  const _SquareHeaderButton({
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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          color: const Color(0xD91E1E23),
        ),
        child: Icon(icon, color: AppColors.text, size: 22),
      ),
    );
  }
}

class _TorboxersHeroCard extends StatelessWidget {
  const _TorboxersHeroCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF2C3651),
              Color(0xFF111827),
              Color(0xFF09090B),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Quick launch',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Open Torboxers',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Search streams, manage your saved playlist, and jump into the player from one place.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.arrow_outward_rounded,
                color: AppColors.background,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Row(
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.text, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PosterWithLabel extends StatelessWidget {
  const _PosterWithLabel({
    required this.title,
    required this.imagePath,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String title;
  final String? imagePath;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: <Widget>[
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: imagePath == null
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
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedContinueCard extends StatelessWidget {
  const _FeaturedContinueCard({
    required this.item,
    required this.onOpen,
    required this.onRemove,
  });

  final WatchHistoryItem item;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: onOpen,
          child: Container(
            width: 280,
            height: 160,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.cardBackground,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                (item.backdropPath ?? item.posterPath) == null
                    ? const ColoredBox(color: AppColors.cardBackground)
                    : Image.network(
                        getImageUrl(item.backdropPath ?? item.posterPath, 'w780'),
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
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _timeLeft(item),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(item),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          value: (item.progress / 100).clamp(0, 1),
                          color: AppColors.primary,
                          backgroundColor: Colors.white.withOpacity(0.2),
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
    required this.onOpen,
    required this.onRemove,
  });

  final WatchHistoryItem item;
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
            height: 165,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                item.posterPath == null
                    ? const ColoredBox(color: AppColors.cardBackground)
                    : Image.network(
                        getImageUrl(item.posterPath, 'w342'),
                        fit: BoxFit.cover,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return const ColoredBox(color: AppColors.cardBackground);
                        },
                      ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: (item.progress / 100).clamp(0, 1),
                    color: AppColors.primary,
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
    required this.onTap,
  });

  final MediaSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 225,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            item.posterPath == null
                ? const ColoredBox(color: AppColors.cardBackground)
                : Image.network(
                    getImageUrl(item.posterPath, 'w342'),
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
