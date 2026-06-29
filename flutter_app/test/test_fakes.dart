import 'package:flutter_app/src/models/tmdb_media_models.dart';
import 'package:flutter_app/src/models/torbox_models.dart';
import 'package:flutter_app/src/models/watch_history_item.dart';
import 'package:flutter_app/src/services/app_settings_repository.dart';
import 'package:flutter_app/src/services/tmdb_media_service.dart';
import 'package:flutter_app/src/services/torbox_api_service.dart';
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
    this.trendingSeries = const <MediaSummary>[
      MediaSummary(
        id: 3,
        mediaType: 'tv',
        title: 'Series One',
        posterPath: null,
        backdropPath: null,
        releaseDate: '2024-02-01',
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
  final List<MediaSummary> trendingSeries;
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
  Future<MediaDetail?> findMediaByExternalId(
    String externalId,
    String mediaType,
  ) async {
    return getMediaDetail(99, mediaType);
  }

  @override
  Future<List<MediaSummary>> getNowPlayingMovies() async => nowPlaying;

  @override
  Future<List<EpisodeItem>> getSeasonEpisodes(
      int tvId, int seasonNumber) async {
    return episodes;
  }

  @override
  Future<List<MediaSummary>> getTrendingMovies() async => trending;

  @override
  Future<List<MediaSummary>> getTrendingSeries() async => trendingSeries;
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

class FakeAppSettingsRepository extends AppSettingsRepository {
  FakeAppSettingsRepository({
    AppSettings initialSettings = const AppSettings(),
  }) : _settings = initialSettings;

  AppSettings _settings;

  @override
  Future<void> clearTorBoxApiKey() async {
    _settings = _settings.copyWith(clearApiKey: true);
  }

  @override
  Future<String?> getTorBoxApiKey() async => _settings.torBoxApiKey;

  @override
  Future<void> clearRealDebridApiKey() async {
    _settings = _settings.copyWith(clearRealDebridApiKey: true);
  }

  @override
  Future<String?> getRealDebridApiKey() async => _settings.realDebridApiKey;

  @override
  Future<String> getPreferredDebridProvider() async =>
      _settings.preferredDebridProvider;

  @override
  Future<bool> getUseAddons() async => _settings.useAddons;

  @override
  Future<bool> getCloudLibraryEnabled() async => _settings.cloudLibraryEnabled;

  @override
  Future<bool> getResolvePlayableLinksEnabled() async =>
      _settings.resolvePlayableLinksEnabled;

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> saveTorBoxApiKey(String apiKey) async {
    _settings = _settings.copyWith(torBoxApiKey: apiKey);
  }

  @override
  Future<void> saveRealDebridApiKey(String apiKey) async {
    _settings = _settings.copyWith(realDebridApiKey: apiKey);
  }

  @override
  Future<void> savePreferredDebridProvider(String provider) async {
    _settings = _settings.copyWith(preferredDebridProvider: provider);
  }

  @override
  Future<void> saveUseAddons(bool value) async {
    _settings = _settings.copyWith(useAddons: value);
  }

  @override
  Future<void> saveCloudLibraryEnabled(bool value) async {
    _settings = _settings.copyWith(cloudLibraryEnabled: value);
  }

  @override
  Future<void> saveResolvePlayableLinksEnabled(bool value) async {
    _settings = _settings.copyWith(resolvePlayableLinksEnabled: value);
  }

  @override
  Future<void> saveTmdbApiKey(String apiKey) async {
    _settings = _settings.copyWith(tmdbApiKey: apiKey);
  }

  @override
  Future<void> clearTmdbApiKey() async {
    _settings = _settings.copyWith(clearTmdbApiKey: true);
  }

  @override
  Future<void> saveMdbListApiKey(String apiKey) async {
    _settings = _settings.copyWith(mdbListApiKey: apiKey);
  }

  @override
  Future<void> clearMdbListApiKey() async {
    _settings = _settings.copyWith(clearMdbListApiKey: true);
  }
}

class FakeTorBoxApiService extends TorBoxApiService {
  FakeTorBoxApiService({
    required this.user,
    this.torrents = const <TorBoxTorrent>[],
    this.shouldThrow = false,
    super.settingsRepository,
  }) : _settingsRepository = settingsRepository;

  final TorBoxUser user;
  final List<TorBoxTorrent> torrents;
  final bool shouldThrow;
  final AppSettingsRepository? _settingsRepository;

  @override
  Future<TorBoxAccountSnapshot> connectAndLoad(String apiKey) async {
    if (shouldThrow) {
      throw const TorBoxApiException(detail: 'Bad API key');
    }
    if (_settingsRepository != null) {
      await _settingsRepository.saveTorBoxApiKey(apiKey);
    }
    return TorBoxAccountSnapshot(user: user, torrents: torrents);
  }

  @override
  Future<TorBoxUser> getUserInfo({String? apiKeyOverride}) async {
    if (shouldThrow) {
      throw const TorBoxApiException(detail: 'Bad API key');
    }
    return user;
  }

  @override
  Future<TorBoxTorrent?> getTorrentByHash(String hash) async {
    for (final TorBoxTorrent torrent in torrents) {
      if (torrent.hash == hash) {
        return torrent;
      }
    }
    return null;
  }

  @override
  Future<List<TorBoxTorrent>> getUserTorrents({
    int? torrentId,
    String? apiKeyOverride,
  }) async {
    if (shouldThrow) {
      throw const TorBoxApiException(detail: 'Bad API key');
    }
    if (torrentId == null) {
      return torrents;
    }
    return torrents
        .where((TorBoxTorrent item) => item.id == torrentId)
        .toList(growable: false);
  }

  @override
  Future<Map<String, bool>> checkCached(List<String> hashes) async {
    return <String, bool>{
      for (final String hash in hashes)
        hash.toLowerCase(): torrents.any(
          (TorBoxTorrent torrent) =>
              torrent.hash.toLowerCase() == hash.toLowerCase() &&
              torrent.isReady,
        ),
    };
  }

  @override
  Future<bool> isConfigured() async => true;

  @override
  Future<TorBoxAccountSnapshot> loadAccountSnapshot() async {
    if (shouldThrow) {
      throw const TorBoxApiException(detail: 'Bad API key');
    }
    return TorBoxAccountSnapshot(user: user, torrents: torrents);
  }

  @override
  Future<bool> verifyApiKey({String? apiKeyOverride}) async => !shouldThrow;
}
