import 'dart:convert';
import 'dart:io';

import '../models/torbox_models.dart';
import 'app_settings_repository.dart';

class TorBoxApiService {
  TorBoxApiService({
    AppSettingsRepository? settingsRepository,
  }) : _settingsRepository = settingsRepository ?? AppSettingsRepository();

  static const String _baseUrl = 'https://api.torbox.app/v1/api';

  final AppSettingsRepository _settingsRepository;

  Future<bool> isConfigured() async {
    final String? apiKey = await _settingsRepository.getTorBoxApiKey();
    return apiKey != null && apiKey.trim().isNotEmpty;
  }

  Future<bool> verifyApiKey() async {
    try {
      await _requestJson(
        'GET',
        Uri.parse('$_baseUrl/user/me'),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<TorBoxUser?> getUserInfo() async {
    try {
      final Map<String, dynamic> payload = await _requestJson(
        'GET',
        Uri.parse('$_baseUrl/user/me'),
      );
      final dynamic data = payload['data'];
      if (payload['success'] == true && data is Map<String, dynamic>) {
        return TorBoxUser.fromJson(data);
      }
    } catch (_) {}

    return null;
  }

  Future<List<TorBoxTorrent>> getUserTorrents({int? torrentId}) async {
    try {
      final Map<String, String> query = <String, String>{
        'bypass_cache': 'true',
      };
      if (torrentId != null) {
        query['id'] = torrentId.toString();
      }

      final Map<String, dynamic> payload = await _requestJson(
        'GET',
        Uri.parse('$_baseUrl/torrents/mylist').replace(queryParameters: query),
      );
      if (payload['success'] != true) {
        return const <TorBoxTorrent>[];
      }

      final dynamic data = payload['data'];
      final List<dynamic> rows = data is List<dynamic>
          ? data
          : data == null
              ? const <dynamic>[]
              : <dynamic>[data];
      return rows
          .map(
            (dynamic item) =>
                TorBoxTorrent.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } on HttpException catch (error) {
      if (error.message.contains('404')) {
        return const <TorBoxTorrent>[];
      }
      return const <TorBoxTorrent>[];
    } catch (_) {
      return const <TorBoxTorrent>[];
    }
  }

  Future<TorBoxTorrent?> getTorrentByHash(String hash) async {
    final List<TorBoxTorrent> torrents = await getUserTorrents();
    final String normalized = hash.toLowerCase();
    for (final TorBoxTorrent torrent in torrents) {
      if (torrent.hash.toLowerCase() == normalized) {
        return torrent;
      }
    }

    return null;
  }

  Future<TorBoxTorrent?> addTorrent(String magnetOrHash) async {
    final String magnet = magnetOrHash.startsWith('magnet:')
        ? magnetOrHash
        : 'magnet:?xt=urn:btih:$magnetOrHash';

    try {
      final Map<String, dynamic> payload = await _requestMultipart(
        Uri.parse('$_baseUrl/torrents/createtorrent'),
        <String, String>{'magnet': magnet},
      );
      if (payload['success'] == true) {
        final dynamic data = payload['data'];
        final Map<String, dynamic>? dataMap =
            data is Map<String, dynamic> ? data : null;
        final int? torrentId =
            (dataMap?['torrent_id'] as num?)?.toInt();
        if (torrentId != null) {
          final List<TorBoxTorrent> torrents =
              await getUserTorrents(torrentId: torrentId);
          if (torrents.isNotEmpty) {
            return torrents.first;
          }
        }
      }

      return await getTorrentByHash(_extractInfoHash(magnetOrHash) ?? magnetOrHash);
    } catch (_) {
      return await getTorrentByHash(_extractInfoHash(magnetOrHash) ?? magnetOrHash);
    }
  }

  Future<bool> deleteTorrent(int torrentId) async {
    try {
      final Map<String, dynamic> payload = await _requestJson(
        'POST',
        Uri.parse('$_baseUrl/torrents/controltorrent'),
        body: <String, dynamic>{
          'torrent_id': torrentId,
          'operation': 'delete',
        },
      );
      return payload['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<TorBoxTorrentFile>> getTorrentFiles(int torrentId) async {
    final List<TorBoxTorrent> torrents = await getUserTorrents(torrentId: torrentId);
    if (torrents.isEmpty) {
      return const <TorBoxTorrentFile>[];
    }

    return torrents.first.files;
  }

  Future<String?> getQuickStreamUrl(int torrentId, [int? fileId]) async {
    try {
      final String? apiKey = await _settingsRepository.getTorBoxApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return null;
      }

      final Uri uri = Uri.parse('$_baseUrl/torrents/requestdl').replace(
        queryParameters: <String, String>{
          'token': apiKey,
          'torrent_id': torrentId.toString(),
          if (fileId != null) 'file_id': fileId.toString(),
        },
      );

      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      try {
        final HttpClientRequest request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final HttpClientResponse response = await request.close();
        final String raw = await response.transform(utf8.decoder).join();
        if (response.statusCode != HttpStatus.ok) {
          return null;
        }

        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final dynamic data = decoded['data'];
          if (data is String && data.isNotEmpty) {
            return data;
          }
        }

        return null;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final String? apiKey = await _settingsRepository.getTorBoxApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const HttpException('TorBox API key not configured');
    }

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final HttpClientRequest request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      if (body != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.write(jsonEncode(body));
      }

      final HttpClientResponse response = await request.close();
      final String raw = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'TorBox request failed with status ${response.statusCode}',
          uri: uri,
        );
      }

      return jsonDecode(raw) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _requestMultipart(
    Uri uri,
    Map<String, String> fields,
  ) async {
    final String? apiKey = await _settingsRepository.getTorBoxApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const HttpException('TorBox API key not configured');
    }

    final String boundary =
        '----streamedflutter${DateTime.now().millisecondsSinceEpoch}';
    final StringBuffer buffer = StringBuffer();
    fields.forEach((String key, String value) {
      buffer
        ..write('--$boundary\r\n')
        ..write('Content-Disposition: form-data; name="$key"\r\n\r\n')
        ..write(value)
        ..write('\r\n');
    });
    buffer.write('--$boundary--\r\n');

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final HttpClientRequest request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(buffer.toString());
      final HttpClientResponse response = await request.close();
      final String raw = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'TorBox multipart request failed with status ${response.statusCode}',
          uri: uri,
        );
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  String? _extractInfoHash(String value) {
    final RegExp matchExpression = RegExp(r'btih:([A-Za-z0-9]+)', caseSensitive: false);
    final RegExpMatch? match = matchExpression.firstMatch(value);
    return match?.group(1)?.toLowerCase();
  }
}
