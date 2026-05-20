import 'package:flutter/material.dart';

import '../constants/layout.dart';
import '../models/favorite_item.dart';
import '../services/favorites_repository.dart';
import '../services/tmdb_image.dart';
import '../theme/app_colors.dart';
import 'movie_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final FavoritesRepository _favoritesRepository = FavoritesRepository();
  List<FavoriteItem> _favorites = const <FavoriteItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
    });

    final List<FavoriteItem> items = await _favoritesRepository.getFavorites();

    if (!mounted) {
      return;
    }

    setState(() {
      _favorites = items;
      _loading = false;
    });
  }

  Future<void> _removeFavorite(FavoriteItem item) async {
    await _favoritesRepository.removeFromFavorites(item.id, item.mediaType);

    if (!mounted) {
      return;
    }

    setState(() {
      _favorites = _favorites
          .where(
            (favorite) =>
                favorite.id != item.id || favorite.mediaType != item.mediaType,
          )
          .toList(growable: false);
    });
  }

  void _openDetail(FavoriteItem item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MovieDetailScreen(
          id: item.id,
          mediaType: item.mediaType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.text,
        backgroundColor: AppColors.surface,
        onRefresh: _loadFavorites,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.horizontalPadding,
                12,
                AppLayout.horizontalPadding,
                24,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    Row(
                      children: <Widget>[
                        const Text(
                          'Favorites',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: AppLayout.largeTitle,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _favorites.length.toString(),
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your favorite movies and TV shows',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionGap),
                    if (_loading)
                      const SizedBox(
                        height: 320,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.text,
                          ),
                        ),
                      )
                    else if (_favorites.isEmpty)
                      const _EmptyFavoritesState()
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _favorites.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppLayout.libraryGridGap,
                          crossAxisSpacing: AppLayout.libraryGridGap,
                          childAspectRatio:
                              AppLayout.libraryCardAspectRatio * 0.76,
                        ),
                        itemBuilder: (BuildContext context, int index) {
                          final FavoriteItem item = _favorites[index];
                          return _FavoriteCard(
                            item: item,
                            onOpen: () => _openDetail(item),
                            onRemove: () => _removeFavorite(item),
                          );
                        },
                      ),
                    const SizedBox(height: 120),
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

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.item,
    required this.onOpen,
    required this.onRemove,
  });

  final FavoriteItem item;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Material(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppLayout.cardRadius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onOpen,
                    child: Image.network(
                      getImageUrl(item.posterPath, 'w342'),
                      fit: BoxFit.cover,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const _PosterFallback();
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _IconPill(
                  icon: Icons.close,
                  onPressed: onRemove,
                ),
              ),
              const Positioned(
                top: 8,
                right: 8,
                child: _StaticPill(
                  child: Icon(
                    Icons.favorite,
                    size: 14,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${item.mediaType == 'movie' ? 'Movie' : 'TV Show'} • ${item.year ?? ''}'
              .trim(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 14,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _StaticPill extends StatelessWidget {
  const _StaticPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.cardBackground,
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          size: 36,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _EmptyFavoritesState extends StatelessWidget {
  const _EmptyFavoritesState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.favorite_border,
            size: 64,
            color: AppColors.cardBackground,
          ),
          SizedBox(height: 20),
          Text(
            'No favorites yet',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Tap the heart icon on any movie or TV show to add it to your favorites.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
