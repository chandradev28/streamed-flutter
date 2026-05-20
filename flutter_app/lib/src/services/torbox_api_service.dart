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

  Future<bool> verifyApiKey({String? apiKeyOverride}) async {
    try {
      await _requestJson(
        'GET',
        Uri.parse('$_baseUrl/user/me').replace(
          queryParameters: const <String, String>{'settings': 'false'},
        ),
        apiKeyOverride: apiKeyOverride,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<TorBoxUser> getUserInfo({String? apiKeyOverride}) async {
    final Map<String, dynamic> payload = await _requestJson(
      'GET',
      Uri.parse('$_baseUrl/user/me').replace(
        queryParameters: const <String, String>{'settings': 'false'},
      ),
      apiKeyOverride: apiKeyOverride,
    );
    final dynamic data = payload['data'];
    if (payload['success'] == true && data is Map<String, dynamic>) {
      return TorBoxUser.fromJson(data);
    }

    throw TorBoxApiException(
      detail: payload['detail'] as String? ?? 'TorBox returned invalid user data.',
      errorCode: payload['error'] as String?,
    );
  }

  Future<List<TorBoxTorrent>> getUserTorrents({
    int? torrentId,
    String? apiKeyOverride,
  }) async {
    final Map<String, String> query = <String, String>{
      'bypass_cache': 'true',
    };
    if (torrentId != null) {
      query['id'] = torrentId.toString();
    }

    final Map<String, dynamic> payload = await _requestJson(
      'GET',
      Uri.parse('$_baseUrl/torrents/mylist').replace(queryParameters: query),
      apiKeyOverride: apiKeyOverride,
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
  }

  Future<TorBoxAccountSnapshot> connectAndLoad(String apiKey) async {
    final String trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw const TorBoxApiException(detail: 'Enter a TorBox API key first.');
    }

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      getUserInfo(apiKeyOverride: trimmed),
      getUserTorrents(apiKeyOverride: trimmed),
    ]);

    await _settingsRepository.saveTorBoxApiKey(trimmed);
    return TorBoxAccountSnapshot(
      user: results[0] as TorBoxUser,
      torrents: results[1] as List<TorBoxTorrent>,
    );
  }

  Future<TorBoxAccountSnapshot> loadAccountSnapshot() async {
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      getUserInfo(),
      getUserTorrents(),
    ]);
    return TorBoxAccountSnapshot(
      user: results[0] as TorBoxUser,
      torrents: results[1] as List<TorBoxTorrent>,
    );
  }

  Future<TorBoxTorrent?> getTorrentByHash(String hash) async {
    try {
      final List<TorBoxTorrent> torrents = await getUserTorrents();
      final String normalized = hash.toLowerCase();
      for (final TorBoxTorrent torrent in torrents) {
        if (torrent.hash.toLowerCase() == normalized) {
          return torrent;
        }
      }
    } catch (_) {}

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

      return await getTorrentByHash(
        _extractInfoHash(magnetOrHash) ?? magnetOrHash,
      );
    } catch (_) {
      try {
        return await getTorrentByHash(
          _extractInfoHash(magnetOrHash) ?? magnetOrHash,
        );
      } catch (_) {
        return null;
      }
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
    try {
      final List<TorBoxTorrent> torrents =
          await getUserTorrents(torrentId: torrentId);
      if (torrents.isEmpty) {
        return const <TorBoxTorrentFile>[];
      }

      return torrents.first.files;
    } catch (_) {
      return const <TorBoxTorrentFile>[];
    }
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
    String? apiKeyOverride,
  }) async {
    final String? apiKey = apiKeyOverride ?? await _settingsRepository.getTorBoxApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const TorBoxApiException(detail: 'TorBox API key not configured.');
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
        throw TorBoxApiException.fromHttpResponse(
          raw,
          statusCode: response.statusCode,
          fallbackDetail: 'TorBox request failed with status ${response.statusCode}.',
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
      throw const TorBoxApiException(detail: 'TorBox API key not configured.');
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
        throw TorBoxApiException.fromHttpResponse(
          raw,
          statusCode: response.statusCode,
          fallbackDetail:
              'TorBox multipart request failed with status ${response.statusCode}.',
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

class TorBoxAccountSnapshot {
  const TorBoxAccountSnapshot({
    required this.user,
    required this.torrents,
  });

  final TorBoxUser user;
  final List<TorBoxTorrent> torrents;
}

class TorBoxApiException implements Exception {
  const TorBoxApiException({
    required this.detail,
    this.errorCode,
    this.statusCode,
  });

  final String detail;
  final String? errorCode;
  final int? statusCode;

  factory TorBoxApiException.fromHttpResponse(
    String raw, {
    required int statusCode,
    required String fallbackDetail,
  }) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return TorBoxApiException(
          detail: decoded['detail'] as String? ?? fallbackDetail,
          errorCode: decoded['error'] as String?,
          statusCode: statusCode,
        );
      }
    } catch (_) {}

    return TorBoxApiException(
      detail: fallbackDetail,
      statusCode: statusCode,
    );
  }

  @override
  String toString() {
    if (errorCode == null || errorCode!.isEmpty) {
      return detail;
    }
    return '$errorCode: $detail';
  }
}
