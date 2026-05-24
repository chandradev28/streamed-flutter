import 'dart:convert';
import 'dart:io';

import '../models/torbox_models.dart';
import '../models/tmdb_media_models.dart';
import 'app_settings_repository.dart';

abstract class MediaCatalogService {
  Future<List<MediaSummary>> getTrendingMovies();
  Future<List<MediaSummary>> getTrendingSeries();
  Future<List<MediaSummary>> getNowPlayingMovies();
  Future<MediaDetail> getMediaDetail(int id, String mediaType);
  Future<List<EpisodeItem>> getSeasonEpisodes(int tvId, int seasonNumber);
}

class TmdbMediaService implements MediaCatalogService {
  TmdbMediaService({
    AppSettingsRepository? settingsRepository,
  }) : _settingsRepository = settingsRepository ?? AppSettingsRepository();

  static const String _apiKey = 'cd45143a9ade518a4381e765c719e68b';
  static const String _baseHost = 'api.themoviedb.org';
  static const int _maxAttempts = 3;

  final AppSettingsRepository _settingsRepository;

  @override
  Future<List<MediaSummary>> getTrendingMovies() async {
    final AppSettings settings = await _settingsRepository.loadSettings();
    final Map<String, dynamic> payload = await _fetch(
      '/3/trending/movie/week',
      <String, String>{'language': settings.tmdbLanguage},
      settings,
    );
    return _readMediaSummaryList(payload).take(10).toList(growable: false);
  }

  @override
  Future<List<MediaSummary>> getTrendingSeries() async {
    final AppSettings settings = await _settingsRepository.loadSettings();
    final Map<String, dynamic> payload = await _fetch(
      '/3/trending/tv/week',
      <String, String>{'language': settings.tmdbLanguage},
      settings,
    );
    return _readMediaSummaryList(payload).take(10).toList(growable: false);
  }

  @override
  Future<List<MediaSummary>> getNowPlayingMovies() async {
    final AppSettings settings = await _settingsRepository.loadSettings();
    final Map<String, dynamic> payload = await _fetch(
      '/3/movie/now_playing',
      <String, String>{
        'language': settings.tmdbLanguage,
        'region': 'US',
      },
      settings,
    );
    return _readMediaSummaryList(payload).take(10).toList(growable: false);
  }

  @override
  Future<MediaDetail> getMediaDetail(int id, String mediaType) async {
    final AppSettings settings = await _settingsRepository.loadSettings();
    final String resource = mediaType == 'movie' ? 'movie' : 'tv';
    final bool enrich = settings.tmdbEnrichmentEnabled;
    final List<String> appends = <String>[
      'external_ids',
      if (enrich && settings.tmdbCreditsEnabled) 'credits',
      if (enrich && settings.tmdbMoreLikeThisEnabled) 'similar',
      if (enrich && settings.tmdbTrailersEnabled) 'videos',
      if (enrich && settings.tmdbArtworkEnabled) 'images',
    ];
    final Map<String, dynamic> detail = await _fetch(
      '/3/$resource/$id',
      <String, String>{
        'language': settings.tmdbLanguage,
        'append_to_response': appends.join(','),
        if (enrich && settings.tmdbArtworkEnabled)
          'include_image_language':
              '${settings.tmdbLanguage.split('-').first},en,null',
      },
      settings,
    );

    final Map<String, dynamic> externalIds =
        detail['external_ids'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
    final Map<String, dynamic> merged = <String, dynamic>{
      ...detail,
      'imdb_id': detail['imdb_id'] ?? externalIds['imdb_id'],
    };
    if (enrich && !settings.tmdbBasicInfoEnabled) {
      merged['overview'] = '';
      merged['genres'] = const <dynamic>[];
      merged['vote_average'] = 0;
      merged['vote_count'] = 0;
    }
    if (enrich && !settings.tmdbDetailsEnabled) {
      merged['runtime'] = 0;
      merged['episode_run_time'] = const <dynamic>[];
      merged['status'] = null;
      merged['production_countries'] = const <dynamic>[];
      merged['original_language'] = null;
    }
    if (enrich && !settings.tmdbNetworksEnabled) {
      merged['networks'] = const <dynamic>[];
    }
    if (enrich && !settings.tmdbProductionsEnabled) {
      merged['production_companies'] = const <dynamic>[];
    }
    if (enrich && !settings.tmdbSeasonPostersEnabled) {
      merged['seasons'] =
          ((merged['seasons'] as List<dynamic>?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> season) => <String, dynamic>{
                    ...season,
                    'poster_path': null,
                  })
              .toList(growable: false);
    }

    return MediaDetail.fromJson(
      merged,
      mediaType: mediaType,
      cast: enrich && settings.tmdbCreditsEnabled
          ? _readCastFromDynamic(detail['credits'])
          : const <CastItem>[],
      similarItems: enrich && settings.tmdbMoreLikeThisEnabled
          ? _readMediaSummaryListFromDynamic(detail['similar']).take(8).toList(
                growable: false,
              )
          : const <MediaSummary>[],
      trailers: enrich && settings.tmdbTrailersEnabled
          ? _readTrailersFromDynamic(detail['videos'])
          : const <MediaTrailer>[],
    );
  }

  @override
  Future<List<EpisodeItem>> getSeasonEpisodes(
      int tvId, int seasonNumber) async {
    final AppSettings settings = await _settingsRepository.loadSettings();
    if (!settings.tmdbEnrichmentEnabled || !settings.tmdbEpisodesEnabled) {
      return const <EpisodeItem>[];
    }
    final Map<String, dynamic> payload = await _fetch(
        '/3/tv/$tvId/season/$seasonNumber',
        <String, String>{'language': settings.tmdbLanguage},
        settings);
    final List<dynamic> results =
        payload['episodes'] as List<dynamic>? ?? const <dynamic>[];
    return results
        .map((dynamic item) =>
            EpisodeItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _fetch(
    String path, [
    Map<String, String> params = const <String, String>{},
    AppSettings? settings,
  ]) async {
    final AppSettings effectiveSettings =
        settings ?? await _settingsRepository.loadSettings();
    final Uri uri = Uri.https(
      _baseHost,
      path,
      <String, String>{
        'api_key': _effectiveApiKey(effectiveSettings),
        ...params,
      },
    );

    Object? lastError;
    for (int attempt = 1; attempt <= _maxAttempts; attempt += 1) {
      try {
        return await _fetchOnce(uri);
      } catch (error) {
        lastError = error;
        if (attempt == _maxAttempts) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }

    throw lastError ?? HttpException('TMDB request failed.', uri: uri);
  }

  String _effectiveApiKey(AppSettings settings) {
    final String personal = (settings.tmdbApiKey ?? '').trim();
    return personal.isEmpty ? _apiKey : personal;
  }

  Future<Map<String, dynamic>> _fetchOnce(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'TMDB request failed with status ${response.statusCode}',
          uri: uri,
        );
      }

      final String raw = await response.transform(utf8.decoder).join();
      return jsonDecode(raw) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  List<MediaSummary> _readMediaSummaryList(Map<String, dynamic> payload) {
    final List<dynamic> results =
        payload['results'] as List<dynamic>? ?? const <dynamic>[];
    return results
        .map((dynamic item) =>
            MediaSummary.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  List<MediaSummary> _readMediaSummaryListFromDynamic(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return const <MediaSummary>[];
    }

    return _readMediaSummaryList(payload);
  }

  List<CastItem> _readCast(Map<String, dynamic> payload) {
    final List<dynamic> cast =
        payload['cast'] as List<dynamic>? ?? const <dynamic>[];
    return cast
        .take(10)
        .map((dynamic item) => CastItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  List<CastItem> _readCastFromDynamic(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return const <CastItem>[];
    }

    return _readCast(payload);
  }

  List<MediaTrailer> _readTrailersFromDynamic(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return const <MediaTrailer>[];
    }

    final List<dynamic> results =
        payload['results'] as List<dynamic>? ?? const <dynamic>[];
    final List<MediaTrailer> trailers = results
        .whereType<Map<String, dynamic>>()
        .map(MediaTrailer.fromJson)
        .where((MediaTrailer trailer) =>
            trailer.url != null &&
            trailer.type.toLowerCase().contains('trailer'))
        .toList(growable: false);
    if (trailers.isNotEmpty) {
      return trailers;
    }
    return results
        .whereType<Map<String, dynamic>>()
        .map(MediaTrailer.fromJson)
        .where((MediaTrailer trailer) => trailer.url != null)
        .toList(growable: false);
  }
}
