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
  static const int _maxAttempts = 3;

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
        'include_adult': 'false',
        'language': 'en-US',
        'page': '1',
      },
    );

    Object? lastError;
    for (int attempt = 1; attempt <= _maxAttempts; attempt += 1) {
      try {
        return await _fetchProviderMovies(uri);
      } catch (error) {
        lastError = error;
        if (attempt == _maxAttempts) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }

    throw lastError ??
        HttpException('TMDB provider discovery failed.', uri: uri);
  }

  Future<List<PlaylistMovie>> _fetchProviderMovies(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;

    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

      final HttpClientResponse response = await request.close().timeout(const Duration(seconds: 12));
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
