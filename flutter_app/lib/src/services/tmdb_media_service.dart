import 'dart:convert';
import 'dart:io';

import '../models/tmdb_media_models.dart';

abstract class MediaCatalogService {
  Future<List<MediaSummary>> getTrendingMovies();
  Future<List<MediaSummary>> getNowPlayingMovies();
  Future<MediaDetail> getMediaDetail(int id, String mediaType);
  Future<List<EpisodeItem>> getSeasonEpisodes(int tvId, int seasonNumber);
}

class TmdbMediaService implements MediaCatalogService {
  const TmdbMediaService();

  static const String _apiKey = 'cd45143a9ade518a4381e765c719e68b';
  static const String _baseHost = 'api.themoviedb.org';

  @override
  Future<List<MediaSummary>> getTrendingMovies() async {
    final Map<String, dynamic> payload =
        await _fetch('/3/trending/movie/week');
    return _readMediaSummaryList(payload).take(10).toList(growable: false);
  }

  @override
  Future<List<MediaSummary>> getNowPlayingMovies() async {
    final Map<String, dynamic> payload = await _fetch('/3/movie/now_playing');
    return _readMediaSummaryList(payload).take(10).toList(growable: false);
  }

  @override
  Future<MediaDetail> getMediaDetail(int id, String mediaType) async {
    final String resource = mediaType == 'movie' ? 'movie' : 'tv';
    final Map<String, dynamic> detail = await _fetch(
      '/3/$resource/$id',
      const <String, String>{
        'append_to_response': 'credits,similar,external_ids',
      },
    );

    final Map<String, dynamic> externalIds =
        detail['external_ids'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
    final Map<String, dynamic> merged = <String, dynamic>{
      ...detail,
      'imdb_id': detail['imdb_id'] ?? externalIds['imdb_id'],
    };

    return MediaDetail.fromJson(
      merged,
      mediaType: mediaType,
      cast: _readCastFromDynamic(detail['credits']),
      similarItems:
          _readMediaSummaryListFromDynamic(detail['similar']).take(8).toList(
                growable: false,
              ),
    );
  }

  @override
  Future<List<EpisodeItem>> getSeasonEpisodes(int tvId, int seasonNumber) async {
    final Map<String, dynamic> payload =
        await _fetch('/3/tv/$tvId/season/$seasonNumber');
    final List<dynamic> results =
        payload['episodes'] as List<dynamic>? ?? const <dynamic>[];
    return results
        .map((dynamic item) => EpisodeItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _fetch(
    String path, [
    Map<String, String> params = const <String, String>{},
  ]) async {
    final Uri uri = Uri.https(
      _baseHost,
      path,
      <String, String>{
        'api_key': _apiKey,
        ...params,
      },
    );

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);

    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final HttpClientResponse response = await request.close();
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
        .map((dynamic item) => MediaSummary.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  List<MediaSummary> _readMediaSummaryListFromDynamic(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return const <MediaSummary>[];
    }

    return _readMediaSummaryList(payload);
  }

  List<CastItem> _readCast(Map<String, dynamic> payload) {
    final List<dynamic> cast = payload['cast'] as List<dynamic>? ?? const <dynamic>[];
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
}
