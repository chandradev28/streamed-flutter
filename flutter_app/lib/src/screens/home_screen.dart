import 'package:flutter/material.dart';

import '../models/tmdb_media_models.dart';
import '../models/watch_history_item.dart';
import '../services/tmdb_image.dart';
import '../services/tmdb_media_service.dart';
import '../services/watch_history_repository.dart';
import '../theme/app_colors.dart';
import 'addons_screen.dart';
import 'episode_screen.dart';
import 'indexer_status_screen.dart';
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

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      _loadOrKeep<MediaSummary>(
        _trending,
        widget.mediaService.getTrendingMovies,
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
      _trending = results[0] as List<MediaSummary>;
      _newReleases = results[1] as List<MediaSummary>;
      _continueWatching = results[2] as List<WatchHistoryItem>;
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

  void _openTorboxers() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TorboxersScreen(),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ProfileScreen(),
      ),
    );
  }

  Future<void> _showMainMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final double maxHeight = MediaQuery.of(context).size.height * 0.88;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C0E),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Menu',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _SquareHeaderButton(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.white.withOpacity(0.04)),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      children: <Widget>[
                        _MenuActionTile(
                          icon: Icons.rocket_launch_outlined,
                          title: 'Torboxers',
                          subtitle: 'Search streams and imported engines',
                          onTap: () {
                            Navigator.of(context).pop();
                            _openTorboxers();
                          },
                        ),
                        const SizedBox(height: 10),
                        _MenuActionTile(
                          icon: Icons.wifi_tethering_rounded,
                          title: 'Indexer Status',
                          subtitle: 'Check Torrentio indexer health',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(this.context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) =>
                                    IndexerStatusScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _MenuActionTile(
                          icon: Icons.extension_outlined,
                          title: 'Stream Addons',
                          subtitle: 'Configure Torrentio, Comet & more',
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(this.context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) =>
                                    AddonsScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _MenuActionTile(
                          icon: Icons.settings_outlined,
                          title: 'App Settings',
                          subtitle:
                              'TorBox account, library, and playback preferences',
                          onTap: () {
                            Navigator.of(context).pop();
                            _openProfile();
                          },
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.white.withOpacity(0.04)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Streamed v1.0.0',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.18),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                          _SquareHeaderButton(
                            key: const ValueKey<String>('home-menu-button'),
                            icon: Icons.menu_rounded,
                            onTap: _showMainMenu,
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Streamed',
                                    style: TextStyle(
                                      color: AppColors.text,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
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
              const _SectionHeader(title: 'Top trending movies'),
              SliverToBoxAdapter(
                child: _loading && _trending.isEmpty
                    ? const _PosterSkeletonRow(
                        height: 282,
                        itemWidth: 160,
                        itemHeight: 240,
                        count: 4,
                      )
                    : SizedBox(
                        height: 282,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 0, 8, 0),
                          scrollDirection: Axis.horizontal,
                          itemCount: _trending.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 16),
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
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (BuildContext context, int index) {
                        final WatchHistoryItem item = _continueWatching[index];
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
                child: _loading && _newReleases.isEmpty
                    ? const _PosterSkeletonRow(
                        height: 235,
                        itemWidth: 155,
                        itemHeight: 185,
                        count: 4,
                      )
                    : SizedBox(
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

class _MenuActionTile extends StatelessWidget {
  const _MenuActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.text, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          height: 1.35,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
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
                        return const ColoredBox(
                            color: AppColors.cardBackground);
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
                        getImageUrl(
                            item.backdropPath ?? item.posterPath, 'w780'),
                        fit: BoxFit.cover,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return const ColoredBox(
                              color: AppColors.cardBackground);
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
                          return const ColoredBox(
                              color: AppColors.cardBackground);
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
