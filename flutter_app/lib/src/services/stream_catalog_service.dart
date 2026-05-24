import 'dart:convert';
import 'dart:io';

import '../models/torbox_models.dart';
import 'real_debrid_api_service.dart';
import 'torbox_api_service.dart';

class StreamCatalogService {
  StreamCatalogService({
    TorBoxApiService? torBoxApiService,
    RealDebridApiService? realDebridApiService,
  })  : torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        realDebridApiService = realDebridApiService ?? RealDebridApiService();

  final TorBoxApiService torBoxApiService;
  final RealDebridApiService realDebridApiService;

  static const String _torrentioBaseUrl = 'https://torrentio.strem.fun';

  static const List<_IndexerDefinition> _indexers = <_IndexerDefinition>[
    _IndexerDefinition(id: 'yts', name: 'YTS'),
    _IndexerDefinition(id: 'eztv', name: 'EZTV'),
    _IndexerDefinition(id: 'rarbg', name: 'RARBG'),
    _IndexerDefinition(id: '1337x', name: '1337x'),
    _IndexerDefinition(id: 'thepiratebay', name: 'The Pirate Bay'),
    _IndexerDefinition(id: 'kickasstorrents', name: 'KickassTorrents'),
    _IndexerDefinition(id: 'torrentgalaxy', name: 'TorrentGalaxy'),
    _IndexerDefinition(id: 'magnetdl', name: 'MagnetDL'),
    _IndexerDefinition(id: 'horriblesubs', name: 'HorribleSubs'),
    _IndexerDefinition(id: 'nyaasi', name: 'NyaaSi'),
    _IndexerDefinition(id: 'tokyotosho', name: 'TokyoTosho'),
    _IndexerDefinition(id: 'anidex', name: 'AniDex'),
    _IndexerDefinition(id: 'rutor', name: 'Rutor'),
    _IndexerDefinition(id: 'rutracker', name: 'Rutracker'),
    _IndexerDefinition(id: 'comando', name: 'Comando'),
    _IndexerDefinition(id: 'bludv', name: 'BluDV'),
    _IndexerDefinition(id: 'micoleaodublado', name: 'MicoLeaoDublado'),
    _IndexerDefinition(id: 'torrent9', name: 'Torrent9'),
    _IndexerDefinition(id: 'ilcorsaronero', name: 'ilCorSaRoNeRo'),
    _IndexerDefinition(id: 'mejortorrent', name: 'MejorTorrent'),
    _IndexerDefinition(id: 'wolfmax4k', name: 'Wolfmax4k'),
    _IndexerDefinition(id: 'cinecalidad', name: 'Cinecalidad'),
    _IndexerDefinition(id: 'besttorrents', name: 'BestTorrents'),
  ];

  Future<IndexerHealth> checkTorrentioHealth() async {
    final DateTime startedAt = DateTime.now();
    try {
      final Map<String, dynamic> manifest =
          await _fetchJson(Uri.parse('$_torrentioBaseUrl/manifest.json'));
      final List<dynamic> streams = await _fetchBuiltInStreamRows(
        imdbId: 'tt0133093',
        mediaType: 'movie',
      );
      final bool manifestOk =
          _readString(manifest['id']) == 'com.stremio.torrentio.addon' ||
              _readString(manifest['name'])?.toLowerCase() == 'torrentio';
      return IndexerHealth(
        isOnline: manifestOk,
        responseTime: DateTime.now().difference(startedAt).inMilliseconds,
        streamCount: streams.length,
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

  Future<List<IndexerStatusDetail>> checkIndexerStatuses() async {
    final List<Future<IndexerStatusDetail>> tasks = _indexers
        .map((_IndexerDefinition indexer) => _probeIndexer(indexer))
        .toList(growable: false);
    return Future.wait(tasks);
  }

  Future<List<StreamSource>> getBuiltInStreams({
    required String imdbId,
    required String mediaType,
    int? seasonNumber,
    int? episodeNumber,
    bool cachedOnly = true,
  }) async {
    final List<dynamic> rows = await _fetchBuiltInStreamRows(
      imdbId: imdbId,
      mediaType: mediaType,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
    final List<StreamSource> streams = rows
        .map((dynamic item) => item as Map<String, dynamic>)
        .map((Map<String, dynamic> item) => _streamFromTorrentio(item))
        .whereType<StreamSource>()
        .toList(growable: false);
    if (!cachedOnly || streams.isEmpty) {
      return streams;
    }

    final List<String> hashes = streams
        .map((StreamSource source) => source.infoHash)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final Map<String, bool> torBoxCached =
        await _checkTorBoxCachedSafely(hashes);
    final Map<String, bool> realDebridCached =
        await _checkRealDebridCachedSafely(hashes);
    return streams
        .map(
          (StreamSource source) => _markCachedProviders(
            source,
            torBoxCached[source.infoHash] == true,
            realDebridCached[source.infoHash] == true,
          ),
        )
        .where((StreamSource source) => source.isCached)
        .toList(growable: false);
  }

  Future<List<StreamSource>> annotateCacheStatus(
    List<StreamSource> streams,
  ) async {
    final List<String> hashes = streams
        .map((StreamSource source) => source.infoHash)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    if (hashes.isEmpty) {
      return streams;
    }

    final Map<String, bool> torBoxCached =
        await _checkTorBoxCachedSafely(hashes);
    final Map<String, bool> realDebridCached =
        await _checkRealDebridCachedSafely(hashes);
    return streams
        .map(
          (StreamSource source) => _markCachedProviders(
            source,
            source.isTorBoxCached || torBoxCached[source.infoHash] == true,
            source.isRealDebridCached ||
                realDebridCached[source.infoHash] == true,
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, bool>> _checkTorBoxCachedSafely(
      List<String> hashes) async {
    try {
      if (!await torBoxApiService.isConfigured()) {
        return const <String, bool>{};
      }
      return torBoxApiService.checkCached(hashes);
    } catch (_) {
      return const <String, bool>{};
    }
  }

  Future<Map<String, bool>> _checkRealDebridCachedSafely(
      List<String> hashes) async {
    try {
      if (!await realDebridApiService.isConfigured()) {
        return const <String, bool>{};
      }
      return realDebridApiService.checkCached(hashes);
    } catch (_) {
      return const <String, bool>{};
    }
  }

  Future<List<dynamic>> _fetchBuiltInStreamRows({
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
    return payload['streams'] as List<dynamic>? ?? const <dynamic>[];
  }

  Future<IndexerStatusDetail> _probeIndexer(_IndexerDefinition indexer) async {
    final DateTime startedAt = DateTime.now();
    final Uri uri = Uri.parse(
      '$_torrentioBaseUrl/providers=${indexer.id}/stream/movie/tt0133093.json',
    );
    try {
      final Map<String, dynamic> payload = await _fetchJson(uri);
      final List<dynamic> streams =
          payload['streams'] as List<dynamic>? ?? const <dynamic>[];
      return IndexerStatusDetail(
        id: indexer.id,
        name: indexer.name,
        isOnline: true,
        responseTime: DateTime.now().difference(startedAt).inMilliseconds,
        streamCount: streams.length,
      );
    } catch (error) {
      return IndexerStatusDetail(
        id: indexer.id,
        name: indexer.name,
        isOnline: false,
        responseTime: DateTime.now().difference(startedAt).inMilliseconds,
        error: error.toString(),
      );
    }
  }

  StreamSource? _streamFromTorrentio(Map<String, dynamic> json) {
    final Map<String, dynamic> behaviorHints =
        json['behaviorHints'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
    final String? directUrl =
        _readString(json['url']) ?? _readString(json['externalUrl']);
    final List<String> sourceTrackers = _extractTrackers(json['sources']);
    final String? infoHash = _normalizeInfoHash(
      _readString(json['infoHash']) ??
          _extractInfoHashFromBehaviorHints(behaviorHints) ??
          _extractInfoHashFromSources(json['sources']),
    );
    if ((directUrl == null || directUrl.isEmpty) &&
        (infoHash == null || infoHash.isEmpty)) {
      return null;
    }

    final String title = _readString(json['name']) ??
        _readString(json['title']) ??
        _readString(behaviorHints['filename']) ??
        'Torrentio stream';
    final String description = _readString(json['description']) ??
        _readString(json['title']) ??
        _readString(behaviorHints['filename']) ??
        '';
    final String text = '$title\n$description';
    final bool cached = _isLikelyCached(text, directUrl, behaviorHints);

    return StreamSource(
      id: 'torrentio:${infoHash ?? directUrl}',
      provider: 'torrentio',
      sourceDisplayName: 'Torrentio',
      title: title,
      description: description,
      quality: _extractQuality(text),
      sizeLabel: _extractSize(text, behaviorHints['videoSize']),
      isCached: cached,
      cacheProvider: cached ? 'TB+' : null,
      infoHash: infoHash,
      directUrl: directUrl,
      fileIndex: ((json['fileIdx'] ?? json['fileIndex']) as num?)?.toInt(),
      fileName: _readString(behaviorHints['filename']),
      videoSizeBytes: (behaviorHints['videoSize'] as num?)?.toInt(),
      magnetUri: _readString(json['magnetUri']) ??
          _buildMagnetUri(infoHash, sourceTrackers),
      sourceTrackers: sourceTrackers,
      streamHeaders: _readProxyRequestHeaders(behaviorHints),
    );
  }

  StreamSource _markCachedProviders(
    StreamSource source,
    bool torBoxCached,
    bool realDebridCached,
  ) {
    final List<String> labels = <String>[
      if (torBoxCached) 'TB+',
      if (realDebridCached) 'RD+',
    ];
    return StreamSource(
      id: source.id,
      provider: source.provider,
      sourceDisplayName: source.sourceDisplayName,
      title: source.title,
      description: source.description,
      quality: source.quality,
      sizeLabel: source.sizeLabel,
      isCached: labels.isNotEmpty,
      cacheProvider: labels.isEmpty ? source.cacheProvider : labels.join(' / '),
      addonId: source.addonId,
      infoHash: source.infoHash,
      directUrl: source.directUrl,
      fileIndex: source.fileIndex,
      fileName: source.fileName,
      videoSizeBytes: source.videoSizeBytes,
      magnetUri: source.magnetUri,
      sourceTrackers: source.sourceTrackers,
      streamHeaders: source.streamHeaders,
    );
  }

  Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 25);
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        final String raw = await response.transform(utf8.decoder).join();
        if (response.statusCode == HttpStatus.forbidden &&
            raw.toLowerCase().contains('cloudflare')) {
          throw HttpException(
            'Torrentio blocked this request with Cloudflare. Try another network, enable stream addons, or use Torboxers engine search.',
            uri: uri,
          );
        }
        throw HttpException(
          'Torrentio request failed with status ${response.statusCode}: ${_compactBody(raw)}',
          uri: uri,
        );
      }

      final String raw = await response.transform(utf8.decoder).join();
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } on FormatException {
        if (raw.toLowerCase().contains('cloudflare')) {
          throw HttpException(
            'Torrentio returned a Cloudflare challenge instead of stream data. Try another network, enable stream addons, or use Torboxers engine search.',
            uri: uri,
          );
        }
        rethrow;
      }
    } finally {
      client.close(force: true);
    }
  }

  String _compactBody(String raw) {
    final String compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 220) {
      return compact;
    }
    return '${compact.substring(0, 220)}...';
  }

  String? _readString(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
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

  String _extractSize(String text, dynamic videoSize) {
    final int? bytes = (videoSize as num?)?.toInt();
    if (bytes != null && bytes > 0) {
      return _formatBytes(bytes);
    }

    final RegExp match =
        RegExp(r'(\d+(?:\.\d+)?)\s?(GB|MB|TB)', caseSensitive: false);
    final RegExpMatch? result = match.firstMatch(text);
    if (result == null) {
      return '';
    }

    return '${result.group(1)} ${result.group(2)!.toUpperCase()}';
  }

  String _formatBytes(int bytes) {
    const List<String> sizes = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int index = 0;
    while (value >= 1024 && index < sizes.length - 1) {
      value /= 1024;
      index += 1;
    }
    final int decimals = value >= 10 || index == 0 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${sizes[index]}';
  }

  bool _isLikelyCached(
    String text,
    String? directUrl,
    Map<String, dynamic> behaviorHints,
  ) {
    if ((behaviorHints['cached'] as bool?) == true) {
      return true;
    }

    final String haystack = '${directUrl ?? ''}\n$text';
    return RegExp(
      r'(cached|instant|torbox|real.?debrid|premiumize|alldebrid|debrid)',
      caseSensitive: false,
    ).hasMatch(haystack);
  }

  String? _extractInfoHashFromBehaviorHints(
      Map<String, dynamic> behaviorHints) {
    final String? bingeGroup = _readString(behaviorHints['bingeGroup']);
    return _extractInfoHash(bingeGroup);
  }

  String? _extractInfoHashFromSources(dynamic sources) {
    if (sources is! List<dynamic>) {
      return null;
    }
    for (final dynamic source in sources) {
      final String? value = _readString(source);
      final String? hash = _extractInfoHash(value);
      if (hash != null) {
        return hash;
      }
    }
    return null;
  }

  List<String> _extractTrackers(dynamic sources) {
    if (sources is! List<dynamic>) {
      return const <String>[];
    }
    return sources
        .map(_readString)
        .whereType<String>()
        .where(
          (String item) =>
              item.startsWith('tracker:', 0) ||
              item.startsWith('http://') ||
              item.startsWith('https://') ||
              item.startsWith('udp://'),
        )
        .toSet()
        .toList(growable: false);
  }

  String? _buildMagnetUri(String? hash, List<String> trackers) {
    if (hash == null || hash.trim().isEmpty) {
      return null;
    }
    final StringBuffer buffer =
        StringBuffer('magnet:?xt=urn:btih:${hash.trim()}');
    for (final String tracker in trackers) {
      final String normalized =
          tracker.replaceFirst(RegExp(r'^tracker:', caseSensitive: false), '');
      if (normalized.trim().isEmpty) {
        continue;
      }
      buffer.write('&tr=${Uri.encodeComponent(normalized.trim())}');
    }
    return buffer.toString();
  }

  Map<String, String> _readProxyRequestHeaders(
    Map<String, dynamic> behaviorHints,
  ) {
    final dynamic proxyHeaders = behaviorHints['proxyHeaders'];
    if (proxyHeaders is! Map<String, dynamic>) {
      return const <String, String>{};
    }
    final dynamic requestHeaders = proxyHeaders['request'];
    if (requestHeaders is! Map<String, dynamic>) {
      return const <String, String>{};
    }
    return requestHeaders.map(
      (String key, dynamic value) => MapEntry<String, String>(
        key,
        value.toString(),
      ),
    );
  }

  String? _extractInfoHash(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final RegExpMatch? match = RegExp(
      r'([A-Fa-f0-9]{40})',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1)?.toLowerCase();
  }

  String? _normalizeInfoHash(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final String? extracted = _extractInfoHash(value);
    return extracted ?? value.toLowerCase();
  }
}

class _IndexerDefinition {
  const _IndexerDefinition({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
