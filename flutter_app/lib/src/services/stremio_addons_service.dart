import 'dart:convert';
import 'dart:io';

import '../models/torbox_models.dart';
import 'local_json_store.dart';

class StremioAddonsService {
  StremioAddonsService({
    LocalJsonStore? store,
  }) : _store = store ?? const LocalJsonStore('.streamed_installed_addons.json');

  final LocalJsonStore _store;

  Future<List<AddonManifest>> getInstalledAddons() async {
    final file = await _store.file();
    if (!await file.exists()) {
      return const <AddonManifest>[];
    }

    try {
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const <AddonManifest>[];
      }

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) => AddonManifest.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } catch (_) {
      return const <AddonManifest>[];
    }
  }

  Future<AddonManifest> installAddon(String manifestUrl) async {
    if (!manifestUrl.startsWith('http://') &&
        !manifestUrl.startsWith('https://')) {
      throw const FormatException('Addon URL must use http or https.');
    }

    final Uri rawUri = Uri.parse(
      manifestUrl.endsWith('manifest.json')
          ? manifestUrl
          : '${manifestUrl.replaceAll(RegExp(r'/$'), '')}/manifest.json',
    );
    final Map<String, dynamic> payload = await _fetchJson(rawUri);

    final String originalUrl = rawUri.toString();
    final Uri normalized = rawUri.replace(path: rawUri.path.replaceAll(RegExp(r'manifest\.json$'), ''));
    final AddonManifest addon = AddonManifest.fromJson(
      <String, dynamic>{
        ...payload,
        'id': (payload['id'] as String?) ?? _makeAddonId(originalUrl),
        'url': normalized.toString().replaceAll(RegExp(r'/$'), ''),
        'originalUrl': originalUrl,
      },
    );

    final List<AddonManifest> installed = await getInstalledAddons();
    final Map<String, AddonManifest> byId = <String, AddonManifest>{
      for (final AddonManifest item in installed) item.id: item,
    };
    byId[addon.id] = addon;
    await _writeAddons(byId.values.toList(growable: false));
    return addon;
  }

  Future<void> removeAddon(String addonId) async {
    final List<AddonManifest> installed = await getInstalledAddons();
    await _writeAddons(
      installed
          .where((AddonManifest addon) => addon.id != addonId)
          .toList(growable: false),
    );
  }

  Future<List<StreamSource>> getStreams({
    required String mediaType,
    required String streamId,
  }) async {
    final List<AddonManifest> addons = await getInstalledAddons();
    final String contentType = mediaType == 'tv' ? 'series' : 'movie';
    final List<StreamSource> results = <StreamSource>[];
    final Set<String> seen = <String>{};

    for (final AddonManifest addon in addons) {
      if (!addon.supportsContent(contentType, streamId)) {
        continue;
      }

      final Uri streamUri = _buildStreamUri(addon, contentType, streamId);
      try {
        final Map<String, dynamic> payload = await _fetchJson(streamUri);
        final List<dynamic> streams =
            payload['streams'] as List<dynamic>? ?? const <dynamic>[];
        for (final dynamic row in streams) {
          final Map<String, dynamic> item = row as Map<String, dynamic>;
          final String? directUrl = item['url'] as String?;
          final String? infoHash = item['infoHash'] as String?;
          if ((directUrl == null || directUrl.isEmpty) &&
              (infoHash == null || infoHash.isEmpty)) {
            continue;
          }

          final String description =
              (item['description'] as String?) ?? (item['title'] as String?) ?? '';
          final String label =
              (item['name'] as String?) ?? (item['title'] as String?) ?? addon.name;
          final String dedupeKey = infoHash ?? directUrl ?? label;
          if (!seen.add('${addon.id}:$dedupeKey')) {
            continue;
          }

          results.add(
            StreamSource(
              id: '${addon.id}:$dedupeKey',
              provider: 'addon',
              sourceDisplayName: addon.name,
              title: label,
              description: description,
              quality: _extractQuality('$label $description'),
              sizeLabel: _extractSize('$label $description'),
              isCached: item['behaviorHints'] is Map<String, dynamic>
                  ? ((item['behaviorHints'] as Map<String, dynamic>)['cached']
                          as bool? ??
                      false)
                  : false,
              infoHash: infoHash,
              directUrl: directUrl,
              fileIndex: (item['fileIdx'] as num?)?.toInt(),
            ),
          );
        }
      } catch (_) {}
    }

    return results;
  }

  Future<void> _writeAddons(List<AddonManifest> addons) async {
    final file = await _store.file();
    await file.writeAsString(
      jsonEncode(addons.map((AddonManifest addon) => addon.toJson()).toList()),
    );
  }

  Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      );
      final HttpClientResponse response = await request.close();
      final String raw = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Addon request failed with status ${response.statusCode}',
          uri: uri,
        );
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Uri _buildStreamUri(AddonManifest addon, String contentType, String streamId) {
    final Uri originalUri = Uri.parse(addon.originalUrl);
    final Uri baseUri = Uri.parse(addon.url);
    return baseUri.replace(
      path: '${baseUri.path}/stream/$contentType/$streamId.json'
          .replaceAll('//', '/'),
      queryParameters: originalUri.queryParameters.isEmpty
          ? null
          : originalUri.queryParameters,
    );
  }

  String _makeAddonId(String url) {
    return url.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').toLowerCase();
  }

  String _extractQuality(String text) {
    final RegExp match = RegExp(r'(2160p|4k|1080p|720p|480p)', caseSensitive: false);
    final RegExpMatch? result = match.firstMatch(text);
    if (result == null) {
      return 'Unknown';
    }

    final String value = result.group(1)!.toUpperCase();
    return value == '2160P' ? '4K' : value;
  }

  String _extractSize(String text) {
    final RegExp match = RegExp(r'(\d+(?:\.\d+)?)\s?(GB|MB|TB)', caseSensitive: false);
    final RegExpMatch? result = match.firstMatch(text);
    if (result == null) {
      return '';
    }

    return '${result.group(1)} ${result.group(2)!.toUpperCase()}';
  }
}
