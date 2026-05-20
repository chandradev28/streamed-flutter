import 'package:flutter_app/src/models/tmdb_media_models.dart';
import 'package:flutter_app/src/models/watch_history_item.dart';
import 'package:flutter_app/src/services/tmdb_media_service.dart';
import 'package:flutter_app/src/services/watch_history_repository.dart';

class FakeMediaService implements MediaCatalogService {
  const FakeMediaService({
    this.trending = const <MediaSummary>[
      MediaSummary(
        id: 1,
        mediaType: 'movie',
        title: 'Trending One',
        posterPath: null,
        backdropPath: null,
        releaseDate: '2024-01-01',
      ),
    ],
    this.nowPlaying = const <MediaSummary>[
      MediaSummary(
        id: 2,
        mediaType: 'movie',
        title: 'Fresh Drop',
        posterPath: null,
        backdropPath: null,
        releaseDate: '2024-05-01',
      ),
    ],
    this.detail,
    this.episodes = const <EpisodeItem>[
      EpisodeItem(
        id: 1,
        name: 'Pilot',
        overview: 'Episode one',
        episodeNumber: 1,
        seasonNumber: 1,
        airDate: '2024-01-01',
        voteAverage: 8.0,
        runtime: 47,
      ),
    ],
  });

  final List<MediaSummary> trending;
  final List<MediaSummary> nowPlaying;
  final MediaDetail? detail;
  final List<EpisodeItem> episodes;

  @override
  Future<MediaDetail> getMediaDetail(int id, String mediaType) async {
    return detail ??
        MediaDetail(
          id: id,
          mediaType: mediaType,
          title: mediaType == 'tv' ? 'Galaxy Squad' : 'Movie Title',
          overview: 'A test overview.',
          posterPath: null,
          backdropPath: null,
          voteAverage: 8.4,
          voteCount: 1000,
          releaseDate: '2024-01-01',
          runtimeMinutes: mediaType == 'tv' ? 48 : 120,
          genres: const <GenreItem>[GenreItem(id: 1, name: 'Sci-Fi')],
          seasons: mediaType == 'tv'
              ? const <SeasonSummary>[
                  SeasonSummary(
                    id: 1,
                    name: 'Season 1',
                    posterPath: null,
                    seasonNumber: 1,
                    episodeCount: 2,
                  ),
                ]
              : const <SeasonSummary>[],
          numberOfSeasons: mediaType == 'tv' ? 1 : 0,
          networks: const <NetworkItem>[
            NetworkItem(id: 1, name: 'StreamNet'),
          ],
          imdbId: null,
          cast: const <CastItem>[
            CastItem(
              id: 1,
              name: 'Alex Star',
              character: 'Captain',
              profilePath: null,
            ),
          ],
          similarItems: const <MediaSummary>[],
        );
  }

  @override
  Future<List<MediaSummary>> getNowPlayingMovies() async => nowPlaying;

  @override
  Future<List<EpisodeItem>> getSeasonEpisodes(int tvId, int seasonNumber) async {
    return episodes;
  }

  @override
  Future<List<MediaSummary>> getTrendingMovies() async => trending;
}

class FakeWatchHistoryRepository implements ContinueWatchingRepository {
  const FakeWatchHistoryRepository({
    this.items = const <WatchHistoryItem>[],
  });

  final List<WatchHistoryItem> items;

  @override
  Future<List<WatchHistoryItem>> getContinueWatching([int limit = 20]) async {
    return items;
  }

  @override
  Future<void> removeFromHistory(String itemId) async {}

  @override
  Future<void> saveProgress(WatchHistoryItem item) async {}
}
