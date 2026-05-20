import 'dart:convert';
import 'dart:io';

import '../models/playlist_movie.dart';

abstract class PlaylistService {
  Future<List<PlaylistMovie>> getMoviesByProvider(int providerId);
}

class TmdbPlaylistService implements PlaylistService {
  const TmdbPlaylistService();

  static const String _apiKey = 'cd45143a9ade518a4381e765c719e68b';
  static const String _baseHost = 'api.themoviedb.org';

  @override
  Future<List<PlaylistMovie>> getMoviesByProvider(int providerId) async {
    final Uri uri = Uri.https(
      _baseHost,
      '/3/discover/movie',
      <String, String>{
        'api_key': _apiKey,
        'with_watch_providers': providerId.toString(),
        'watch_region': 'US',
        'sort_by': 'popularity.desc',
        'page': '1',
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
          'TMDB provider discovery failed with status ${response.statusCode}',
          uri: uri,
        );
      }

      final String raw = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> payload =
          jsonDecode(raw) as Map<String, dynamic>;
      final List<dynamic> results =
          payload['results'] as List<dynamic>? ?? const <dynamic>[];

      return results
          .take(10)
          .map(
            (dynamic item) =>
                PlaylistMovie.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } finally {
      client.close(force: true);
    }
  }
}
