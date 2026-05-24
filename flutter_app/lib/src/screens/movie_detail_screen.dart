import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/favorite_item.dart';
import '../models/tmdb_media_models.dart';
import '../services/favorites_repository.dart';
import '../services/mdblist_api_service.dart';
import '../services/tmdb_image.dart';
import '../services/tmdb_media_service.dart';
import '../theme/app_colors.dart';
import 'episode_screen.dart';
import 'magnet_screen.dart';
import 'streamed_sources_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  MovieDetailScreen({
    super.key,
    required this.id,
    required this.mediaType,
    MediaCatalogService? mediaService,
    MdbListApiService? mdbListApiService,
    FavoritesRepository? favoritesRepository,
  })  : mediaService = mediaService ?? TmdbMediaService(),
        mdbListApiService = mdbListApiService ?? MdbListApiService(),
        favoritesRepository = favoritesRepository ?? FavoritesRepository();

  final int id;
  final String mediaType;
  final MediaCatalogService mediaService;
  final MdbListApiService mdbListApiService;
  final FavoritesRepository favoritesRepository;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  static const int _initialRetryCount = 3;

  MediaDetail? _detail;
  List<ExternalRating> _externalRatings = const <ExternalRating>[];
  bool _loading = true;
  bool _showFullDescription = false;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadFavoriteState();
  }

  Future<void> _loadDetail({int retryCount = _initialRetryCount}) async {
    if (!_loading) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final MediaDetail detail =
          await widget.mediaService.getMediaDetail(widget.id, widget.mediaType);
      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
        _loading = false;
      });
      _loadExternalRatings(detail);
    } catch (_) {
      if (retryCount > 0) {
        // Exponential backoff: 400ms, 800ms, 1200ms
        final int delayMs = 400 * (_initialRetryCount - retryCount + 1);
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        if (!mounted) {
          return;
        }
        await _loadDetail(retryCount: retryCount - 1);
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadExternalRatings(MediaDetail detail) async {
    final List<ExternalRating> ratings =
        await widget.mdbListApiService.getRatings(detail);
    if (!mounted) {
      return;
    }
    setState(() {
      _externalRatings = ratings;
    });
  }

  Future<void> _loadFavoriteState() async {
    final bool favorited = await widget.favoritesRepository.isFavorite(
      widget.id,
      widget.mediaType,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isFavorited = favorited;
    });
  }

  Future<void> _toggleFavorite() async {
    final MediaDetail? detail = _detail;
    if (detail == null) {
      return;
    }

    final FavoriteItem item = FavoriteItem(
      id: detail.id,
      mediaType: detail.mediaType,
      title: detail.title,
      posterPath: detail.posterPath,
      backdropPath: detail.backdropPath,
      rating: detail.voteAverage,
      year: _year(detail.releaseDate),
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final bool nextState =
        await widget.favoritesRepository.toggleFavorite(item);
    if (!mounted) {
      return;
    }

    setState(() {
      _isFavorited = nextState;
    });
  }

  void _showPlaybackTools() {
    final MediaDetail? detail = _detail;
    if (detail == null) {
      return;
    }

    if (detail.mediaType == 'tv') {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => EpisodeScreen(
            tvId: detail.id,
            initialSeason: 1,
            showName: detail.title,
            posterPath: detail.posterPath,
            mediaService: widget.mediaService,
          ),
        ),
      );
      return;
    }

    if ((detail.imdbId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'This title is missing an IMDb ID, so Torboxers cannot search it yet.'),
        ),
      );
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => StreamedSourcesScreen(
          title: detail.title,
          posterPath: detail.posterPath,
          mediaType: detail.mediaType,
          imdbId: detail.imdbId!,
          tmdbId: detail.id,
        ),
      ),
    );
  }

  void _openRelated(MediaSummary item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MovieDetailScreen(
          id: item.id,
          mediaType: item.mediaType,
          mediaService: widget.mediaService,
          favoritesRepository: widget.favoritesRepository,
        ),
      ),
    );
  }

  Future<void> _openTrailer(MediaTrailer trailer) async {
    final Uri? url = trailer.url;
    if (url == null) {
      return;
    }
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _openSeason(SeasonSummary season) {
    final MediaDetail? detail = _detail;
    if (detail == null) {
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EpisodeScreen(
          tvId: detail.id,
          initialSeason: season.seasonNumber,
          showName: detail.title,
          posterPath: season.posterPath ?? detail.posterPath,
          mediaService: widget.mediaService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.text),
        ),
      );
    }

    final MediaDetail? detail = _detail;
    if (detail == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Could not load this title.',
                  style: TextStyle(color: AppColors.text),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _loadDetail,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool isMovie = detail.mediaType == 'movie';
    final String genres =
        detail.genres.take(2).map((GenreItem item) => item.name).join(', ');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  (detail.backdropPath ?? detail.posterPath) == null
                      ? const ColoredBox(color: AppColors.background)
                      : Image.network(
                          getImageUrl(
                            detail.backdropPath ?? detail.posterPath,
                            'original',
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return const ColoredBox(
                                color: AppColors.background);
                          },
                        ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                          const Color(0xF20A0A0A),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _CircleActionButton(
                          icon: Icons.chevron_left,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        Column(
                          children: <Widget>[
                            const SizedBox(height: 2),
                            _CircleActionButton(
                              icon: _isFavorited
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              iconColor: _isFavorited
                                  ? AppColors.accent
                                  : AppColors.text,
                              onTap: _toggleFavorite,
                            ),
                            const SizedBox(height: 10),
                            _CircleActionButton(
                              icon: Icons.download_outlined,
                              onTap: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) =>
                                        MagnetScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.27,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              detail.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              genres.isEmpty ? 'Drama' : genres,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _RatingsRow(
                              score: detail.voteAverage,
                              votes: detail.voteCount,
                              externalRatings: _externalRatings,
                            ),
                            if (detail.trailers.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openTrailer(detail.trailers.first),
                                icon: const Icon(Icons.play_circle_outline),
                                label: Text(
                                  detail.trailers.first.name.isEmpty
                                      ? 'Watch trailer'
                                      : detail.trailers.first.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                _MetaText(text: _year(detail.releaseDate)),
                                const _Dot(),
                                _MetaText(text: '${detail.runtimeMinutes} min'),
                                if (!isMovie &&
                                    detail.numberOfSeasons > 0) ...<Widget>[
                                  const _Dot(),
                                  _MetaText(
                                    text: '${detail.numberOfSeasons} Seasons',
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              detail.overview.isEmpty
                                  ? 'No description available.'
                                  : detail.overview,
                              maxLines: _showFullDescription ? null : 3,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            if (detail.overview.length > 100)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showFullDescription =
                                        !_showFullDescription;
                                  });
                                },
                                child: Text(
                                  _showFullDescription ? 'less' : 'more',
                                  style: const TextStyle(
                                    color: Color(0xFFF5C518),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.text,
                                  foregroundColor: AppColors.background,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: _showPlaybackTools,
                                child: const Text(
                                  'Watch now',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isMovie &&
                    detail.seasons
                        .any((SeasonSummary season) => season.seasonNumber > 0))
                  SliverToBoxAdapter(
                    child: _HorizontalSection(
                      title: 'Seasons',
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: detail.seasons
                              .where((SeasonSummary season) =>
                                  season.seasonNumber > 0)
                              .map(
                                (SeasonSummary season) => Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: _SeasonCard(
                                    season: season,
                                    fallbackPosterPath: detail.posterPath,
                                    onTap: () => _openSeason(season),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ),
                if (detail.similarItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalSection(
                      title: 'Related ${isMovie ? 'movies' : 'shows'}',
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: detail.similarItems
                              .map(
                                (MediaSummary item) => Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: _PosterTile(
                                    imagePath: item.posterPath,
                                    width: 140,
                                    height: 200,
                                    borderRadius: 14,
                                    onTap: () => _openRelated(item),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ),
                if (detail.cast.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalSection(
                      title: 'Top cast',
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: detail.cast
                              .map(
                                (CastItem member) => Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: _CastCard(member: member),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ),
                if (detail.productionCompanies.isNotEmpty ||
                    detail.networks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalSection(
                      title: 'Studios & networks',
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: <Widget>[
                            ...detail.productionCompanies.map(
                              (ProductionCompanyItem company) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _TextChip(label: company.name),
                              ),
                            ),
                            ...detail.networks.map(
                              (NetworkItem network) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _TextChip(label: network.name),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.onTap,
    this.iconColor = AppColors.text,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.15),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

class _RatingsRow extends StatelessWidget {
  const _RatingsRow({
    required this.score,
    required this.votes,
    required this.externalRatings,
  });

  final double score;
  final int votes;
  final List<ExternalRating> externalRatings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _RatingChip(
          label: 'TMDB',
          score: score.toStringAsFixed(1),
          votes: votes,
          icon: Icons.star,
        ),
        ...externalRatings.map(
          (ExternalRating rating) => _RatingChip(
            label: rating.label,
            score: rating.score,
            votes: rating.votes,
            icon: Icons.add_chart_rounded,
          ),
        ),
      ],
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.label,
    required this.score,
    required this.icon,
    this.votes,
  });

  final String label;
  final String score;
  final IconData icon;
  final int? votes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: const Color(0xFFF5C518)),
          const SizedBox(width: 8),
          Text(
            score,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (votes != null && votes! > 0)
                Text(
                  '$votes votes',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textSubtle,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextChip extends StatelessWidget {
  const _TextChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 13,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '•',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}

class _HorizontalSection extends StatelessWidget {
  const _HorizontalSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({
    required this.season,
    required this.fallbackPosterPath,
    required this.onTap,
  });

  final SeasonSummary season;
  final String? fallbackPosterPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 100,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.cardBackground,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            (season.posterPath ?? fallbackPosterPath) == null
                ? const ColoredBox(color: AppColors.cardBackground)
                : Image.network(
                    getImageUrl(
                        season.posterPath ?? fallbackPosterPath, 'w185'),
                    fit: BoxFit.cover,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const ColoredBox(color: AppColors.cardBackground);
                    },
                  ),
            Container(
              color: Colors.black.withOpacity(0.4),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(10),
              child: Text(
                season.name,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({
    required this.imagePath,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.onTap,
  });

  final String? imagePath;
  final double width;
  final double height;
  final double borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: width,
          height: height,
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
    );
  }
}

class _CastCard extends StatelessWidget {
  const _CastCard({required this.member});

  final CastItem member;

  @override
  Widget build(BuildContext context) {
    final List<String> nameParts =
        member.name.split(' ').where((String part) => part.isNotEmpty).toList();

    return SizedBox(
      width: 85,
      child: Column(
        children: <Widget>[
          Container(
            width: 80,
            height: 80,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.15), width: 2),
            ),
            child: member.profilePath == null
                ? ColoredBox(
                    color: const Color(0xFF333333),
                    child: Center(
                      child: Text(
                        nameParts.isEmpty
                            ? '?'
                            : nameParts.first.substring(0, 1),
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : Image.network(
                    getImageUrl(member.profilePath, 'w185'),
                    fit: BoxFit.cover,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const ColoredBox(color: Color(0xFF333333));
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            nameParts.isEmpty ? member.name : nameParts.first,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            member.character.split('/').first.split('(').first.trim(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSubtle,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

String _year(String date) => date.isEmpty ? '' : date.split('-').first;
