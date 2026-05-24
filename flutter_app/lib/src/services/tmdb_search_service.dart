import 'dart:convert';
import 'dart:io';

import '../models/search_result.dart';

abstract class SearchService {
  Future<List<SearchResult>> searchMulti(String query);
}

class TmdbSearchService implements SearchService {
  const TmdbSearchService();

  static const String _apiKey = 'cd45143a9ade518a4381e765c719e68b';
  static const String _baseHost = 'api.themoviedb.org';

  @override
  Future<List<SearchResult>> searchMulti(String query) async {
    final Uri uri = Uri.https(
      _baseHost,
      '/3/search/multi',
      <String, String>{
        'api_key': _apiKey,
        'query': query,
        'page': '1',
        'include_adult': 'false',
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
          'TMDB search failed with status ${response.statusCode}',
          uri: uri,
        );
      }

      final String raw = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> payload =
          jsonDecode(raw) as Map<String, dynamic>;
      final List<dynamic> results =
          payload['results'] as List<dynamic>? ?? const <dynamic>[];

      return results
          .where((dynamic item) {
            final String? mediaType =
                (item as Map<String, dynamic>)['media_type'] as String?;
            return mediaType == 'movie' || mediaType == 'tv';
          })
          .map(
            (dynamic item) =>
                SearchResult.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } finally {
      client.close(force: true);
    }
  }
}
