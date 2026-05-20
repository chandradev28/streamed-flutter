import 'dart:convert';
import 'dart:io';

import '../models/torbox_models.dart';

class StreamCatalogService {
  const StreamCatalogService();

  static const String _torrentioBaseUrl = 'https://torrentio.strem.fun';

  Future<IndexerHealth> checkTorrentioHealth() async {
    final DateTime startedAt = DateTime.now();
    try {
      final List<StreamSource> results = await getBuiltInStreams(
        imdbId: 'tt0133093',
        mediaType: 'movie',
      );
      return IndexerHealth(
        isOnline: results.isNotEmpty,
        responseTime: DateTime.now().difference(startedAt).inMilliseconds,
        streamCount: results.length,
      );
    } catch (error) {
      return IndexerHealth(
        isOnline: false,
        responseTime: DateTime.now().difference(startedAt).inMilliseconds,
        streamCount: 0,
        error: error.toString(),
      );
    }
  }

  Future<List<StreamSource>> getBuiltInStreams({
    required String imdbId,
    required String mediaType,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    final String path = mediaType == 'tv'
        ? '/stream/series/$imdbId:${seasonNumber ?? 1}:${episodeNumber ?? 1}.json'
        : '/stream/movie/$imdbId.json';
    final Map<String, dynamic> payload =
        await _fetchJson(Uri.parse('$_torrentioBaseUrl$path'));
    final List<dynamic> rows =
        payload['streams'] as List<dynamic>? ?? const <dynamic>[];
    return rows
        .map((dynamic item) => item as Map<String, dynamic>)
        .map((Map<String, dynamic> item) => _streamFromTorrentio(item))
        .whereType<StreamSource>()
        .toList(growable: false);
  }

  StreamSource? _streamFromTorrentio(Map<String, dynamic> json) {
    final String? directUrl = json['url'] as String?;
    final String? infoHash = json['infoHash'] as String?;
    if ((directUrl == null || directUrl.isEmpty) &&
        (infoHash == null || infoHash.isEmpty)) {
      return null;
    }

    final String title = (json['name'] as String?) ??
        (json['title'] as String?) ??
        'Torrentio stream';
    final String description = (json['description'] as String?) ??
        (json['title'] as String?) ??
        '';
    final String text = '$title\n$description';

    return StreamSource(
      id: 'torrentio:${infoHash ?? directUrl}',
      provider: 'torrentio',
      sourceDisplayName: 'Torrentio',
      title: title,
      description: description,
      quality: _extractQuality(text),
      sizeLabel: _extractSize(text),
      isCached: _isLikelyCached(text, json),
      infoHash: infoHash,
      directUrl: directUrl,
      fileIndex: (json['fileIdx'] as num?)?.toInt(),
    );
  }

  Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse response = await request.close();
      final String raw = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Request failed with status ${response.statusCode}',
          uri: uri,
        );
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  String _extractQuality(String text) {
    final RegExp match =
        RegExp(r'(2160p|4k|1080p|720p|480p)', caseSensitive: false);
    final RegExpMatch? result = match.firstMatch(text);
    if (result == null) {
      return 'Unknown';
    }

    final String value = result.group(1)!.toUpperCase();
    return value == '2160P' ? '4K' : value;
  }

  String _extractSize(String text) {
    final RegExp match =
        RegExp(r'(\d+(?:\.\d+)?)\s?(GB|MB|TB)', caseSensitive: false);
    final RegExpMatch? result = match.firstMatch(text);
    if (result == null) {
      return '';
    }

    return '${result.group(1)} ${result.group(2)!.toUpperCase()}';
  }

  bool _isLikelyCached(String text, Map<String, dynamic> json) {
    if (json['behaviorHints'] is Map<String, dynamic>) {
      if (((json['behaviorHints'] as Map<String, dynamic>)['cached']) == true) {
        return true;
      }
    }

    return RegExp(
      r'(cached|instant|torbox|rd|real.?debrid|âš¡)',
      caseSensitive: false,
    ).hasMatch(text);
  }
}
