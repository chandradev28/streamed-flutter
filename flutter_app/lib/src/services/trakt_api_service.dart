import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/torbox_models.dart';
import 'app_settings_repository.dart';

class TraktApiService {
  TraktApiService({
    AppSettingsRepository? settingsRepository,
  }) : settingsRepository = settingsRepository ?? AppSettingsRepository();

  static const String _baseUrl = 'https://api.trakt.tv';
  static const int _apiVersion = 2;
  static const String _bundledClientId =
      String.fromEnvironment('TRAKT_CLIENT_ID', defaultValue: '');
  static const String _bundledClientSecret =
      String.fromEnvironment('TRAKT_CLIENT_SECRET', defaultValue: '');

  final AppSettingsRepository settingsRepository;

  bool get hasBundledCredentials =>
      _bundledClientId.trim().isNotEmpty &&
      _bundledClientSecret.trim().isNotEmpty;

  Future<bool> hasUsableCredentials() async {
    final AppSettings settings = await settingsRepository.loadSettings();
    return _effectiveClientId(settings).isNotEmpty &&
        _effectiveClientSecret(settings).isNotEmpty;
  }

  Future<void> ensureBundledCredentialsSaved() async {
    if (!hasBundledCredentials) {
      return;
    }
    final AppSettings settings = await settingsRepository.loadSettings();
    final String currentId = (settings.traktClientId ?? '').trim();
    final String currentSecret = (settings.traktClientSecret ?? '').trim();
    if (currentId.isNotEmpty && currentSecret.isNotEmpty) {
      return;
    }
    await settingsRepository.saveSettings(
      settings.copyWith(
        traktClientId: currentId.isEmpty ? _bundledClientId.trim() : currentId,
        traktClientSecret:
            currentSecret.isEmpty ? _bundledClientSecret.trim() : currentSecret,
      ),
    );
  }

  Future<bool> isConnected() async {
    final AppSettings settings = await settingsRepository.loadSettings();
    return (settings.traktAccessToken ?? '').trim().isNotEmpty &&
        _effectiveClientId(settings).isNotEmpty;
  }

  Future<void> saveCredentials({
    required String clientId,
    required String clientSecret,
  }) async {
    final AppSettings settings = await settingsRepository.loadSettings();
    await settingsRepository.saveSettings(
      settings.copyWith(
        traktClientId: clientId.trim(),
        traktClientSecret: clientSecret.trim(),
      ),
    );
  }

  Future<TraktDeviceCode> createDeviceCode() async {
    final AppSettings settings = await settingsRepository.loadSettings();
    final String clientId = _effectiveClientId(settings);
    if (clientId.isEmpty) {
      throw const TraktApiException(
        detail:
            'This build does not have Trakt app credentials yet. Add your own in Advanced setup.',
      );
    }

    final Map<String, dynamic> payload = await _requestJson(
      'POST',
      Uri.parse('$_baseUrl/oauth/device/code'),
      body: <String, dynamic>{'client_id': clientId},
      authenticated: false,
    );
    return TraktDeviceCode.fromJson(payload);
  }

  Future<TraktUser> exchangeDeviceCode(String deviceCode) async {
    final AppSettings settings = await settingsRepository.loadSettings();
    final String clientId = _effectiveClientId(settings);
    final String clientSecret = _effectiveClientSecret(settings);
    if (clientId.isEmpty || clientSecret.isEmpty) {
      throw const TraktApiException(
        detail:
            'This build does not have complete Trakt app credentials yet. Add them in Advanced setup.',
      );
    }

    final Map<String, dynamic> payload = await _requestJson(
      'POST',
      Uri.parse('$_baseUrl/oauth/device/token'),
      body: <String, dynamic>{
        'code': deviceCode,
        'client_id': clientId,
        'client_secret': clientSecret,
      },
      authenticated: false,
    );

    final AppSettings tokenSettings = await _saveTokenPayload(
      settings,
      payload,
    );
    final TraktUser user = await getUser(settingsOverride: tokenSettings);
    await settingsRepository.saveSettings(
      tokenSettings.copyWith(
        traktUsername: user.username,
        traktLastSyncAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return user;
  }

  Future<void> disconnect() async {
    final AppSettings settings = await settingsRepository.loadSettings();
    await settingsRepository.saveSettings(
      settings.copyWith(clearTraktToken: true),
    );
  }

  Future<TraktUser> getUser({AppSettings? settingsOverride}) async {
    final Map<String, dynamic> payload = await _requestJson(
      'GET',
      Uri.parse('$_baseUrl/users/settings'),
      settingsOverride: settingsOverride,
    );
    final dynamic user = payload['user'];
    if (user is Map<String, dynamic>) {
      return TraktUser.fromJson(user);
    }
    return const TraktUser(username: 'Trakt user', name: null);
  }

  Future<List<TraktWatchlistItem>> getWatchlist() async {
    final List<dynamic> payload = await _requestJsonList(
      'GET',
      Uri.parse('$_baseUrl/sync/watchlist'),
    );
    return payload
        .whereType<Map<String, dynamic>>()
        .map(TraktWatchlistItem.fromJson)
        .where((TraktWatchlistItem item) => item.tmdbId != null)
        .toList(growable: false);
  }

  Future<void> scrobbleStart(TraktScrobbleItem item) async {
    await _scrobble('start', item);
  }

  Future<void> scrobblePause(TraktScrobbleItem item) async {
    await _scrobble('pause', item);
  }

  Future<void> scrobbleStop(TraktScrobbleItem item) async {
    await _scrobble('stop', item);
  }

  Future<void> _scrobble(String action, TraktScrobbleItem item) async {
    final AppSettings settings = await settingsRepository.loadSettings();
    if (!settings.traktScrobbleEnabled ||
        (settings.traktAccessToken ?? '').trim().isEmpty) {
      return;
    }
    await _requestJson(
      'POST',
      Uri.parse('$_baseUrl/scrobble/$action'),
      body: item.toJson(),
      settingsOverride: settings,
    );
  }

  Future<AppSettings> _saveTokenPayload(
    AppSettings settings,
    Map<String, dynamic> payload,
  ) async {
    final int expiresIn = (payload['expires_in'] as num?)?.toInt() ?? 0;
    final int expiresAt = DateTime.now()
        .add(Duration(seconds: expiresIn > 0 ? expiresIn : 7776000))
        .millisecondsSinceEpoch;
    final AppSettings updated = settings.copyWith(
      traktAccessToken: payload['access_token'] as String?,
      traktRefreshToken: payload['refresh_token'] as String?,
      traktTokenExpiresAt: expiresAt,
    );
    await settingsRepository.saveSettings(updated);
    return updated;
  }

  Future<AppSettings> _ensureFreshToken(AppSettings settings) async {
    final int? expiresAt = settings.traktTokenExpiresAt;
    final String refreshToken = (settings.traktRefreshToken ?? '').trim();
    final String clientId = _effectiveClientId(settings);
    final String clientSecret = _effectiveClientSecret(settings);
    final bool stillValid = expiresAt != null &&
        expiresAt >
            DateTime.now()
                .add(const Duration(minutes: 10))
                .millisecondsSinceEpoch;
    if (stillValid ||
        refreshToken.isEmpty ||
        clientId.isEmpty ||
        clientSecret.isEmpty) {
      return settings;
    }

    final Map<String, dynamic> payload = await _requestJson(
      'POST',
      Uri.parse('$_baseUrl/oauth/token'),
      body: <String, dynamic>{
        'refresh_token': refreshToken,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': 'urn:ietf:wg:oauth:2.0:oob',
        'grant_type': 'refresh_token',
      },
      authenticated: false,
    );
    return _saveTokenPayload(settings, payload);
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    AppSettings? settingsOverride,
  }) async {
    final dynamic decoded = await _requestDecoded(
      method,
      uri,
      body: body,
      authenticated: authenticated,
      settingsOverride: settingsOverride,
    );
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const TraktApiException(detail: 'Trakt returned invalid data.');
  }

  Future<List<dynamic>> _requestJsonList(
    String method,
    Uri uri, {
    AppSettings? settingsOverride,
  }) async {
    final dynamic decoded = await _requestDecoded(
      method,
      uri,
      settingsOverride: settingsOverride,
    );
    if (decoded is List<dynamic>) {
      return decoded;
    }
    return const <dynamic>[];
  }

  Future<dynamic> _requestDecoded(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    AppSettings? settingsOverride,
  }) async {
    AppSettings settings =
        settingsOverride ?? await settingsRepository.loadSettings();
    if (authenticated) {
      settings = await _ensureFreshToken(settings);
    }

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final HttpClientRequest request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('trakt-api-version', _apiVersion.toString());
      final String clientId = _effectiveClientId(settings);
      if (clientId.isNotEmpty) {
        request.headers.set('trakt-api-key', clientId);
      }
      if (authenticated) {
        final String token = (settings.traktAccessToken ?? '').trim();
        if (token.isEmpty) {
          throw const TraktApiException(detail: 'Trakt is not connected.');
        }
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 30));
      final String raw = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TraktApiException.fromHttpResponse(
          raw,
          statusCode: response.statusCode,
        );
      }
      if (raw.trim().isEmpty) {
        return const <String, dynamic>{};
      }
      return jsonDecode(raw);
    } on TraktApiException {
      rethrow;
    } on TimeoutException {
      throw const TraktApiException(detail: 'Trakt request timed out.');
    } on SocketException catch (error) {
      throw TraktApiException(detail: 'Network error: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  String _effectiveClientId(AppSettings settings) {
    final String saved = (settings.traktClientId ?? '').trim();
    return saved.isNotEmpty ? saved : _bundledClientId.trim();
  }

  String _effectiveClientSecret(AppSettings settings) {
    final String saved = (settings.traktClientSecret ?? '').trim();
    return saved.isNotEmpty ? saved : _bundledClientSecret.trim();
  }
}

class TraktDeviceCode {
  const TraktDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUrl;
  final int expiresIn;
  final int interval;

  factory TraktDeviceCode.fromJson(Map<String, dynamic> json) {
    return TraktDeviceCode(
      deviceCode: json['device_code'] as String? ?? '',
      userCode: json['user_code'] as String? ?? '',
      verificationUrl: json['verification_url'] as String? ??
          json['verification_uri'] as String? ??
          'https://trakt.tv/activate',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 600,
      interval: (json['interval'] as num?)?.toInt() ?? 5,
    );
  }
}

class TraktUser {
  const TraktUser({
    required this.username,
    required this.name,
  });

  final String username;
  final String? name;

  factory TraktUser.fromJson(Map<String, dynamic> json) {
    return TraktUser(
      username: json['username'] as String? ?? 'Trakt user',
      name: json['name'] as String?,
    );
  }
}

class TraktWatchlistItem {
  const TraktWatchlistItem({
    required this.title,
    required this.mediaType,
    required this.tmdbId,
    required this.year,
  });

  final String title;
  final String mediaType;
  final int? tmdbId;
  final int? year;

  factory TraktWatchlistItem.fromJson(Map<String, dynamic> json) {
    final dynamic movie = json['movie'];
    final dynamic show = json['show'];
    final Map<String, dynamic>? item =
        movie is Map<String, dynamic> ? movie : show as Map<String, dynamic>?;
    final dynamic ids = item?['ids'];
    return TraktWatchlistItem(
      title: item?['title'] as String? ?? 'Trakt title',
      mediaType: movie is Map<String, dynamic> ? 'movie' : 'tv',
      tmdbId:
          ids is Map<String, dynamic> ? (ids['tmdb'] as num?)?.toInt() : null,
      year: item?['year'] as int?,
    );
  }
}

class TraktScrobbleItem {
  const TraktScrobbleItem({
    required this.title,
    required this.mediaType,
    required this.tmdbId,
    required this.progress,
    this.seasonNumber,
    this.episodeNumber,
  });

  final String title;
  final String mediaType;
  final int tmdbId;
  final double progress;
  final int? seasonNumber;
  final int? episodeNumber;

  Map<String, dynamic> toJson() {
    if (mediaType == 'tv' && seasonNumber != null && episodeNumber != null) {
      return <String, dynamic>{
        'progress': progress,
        'show': <String, dynamic>{
          'title': title,
          'ids': <String, dynamic>{'tmdb': tmdbId},
        },
        'episode': <String, dynamic>{
          'season': seasonNumber,
          'number': episodeNumber,
        },
      };
    }
    return <String, dynamic>{
      'progress': progress,
      'movie': <String, dynamic>{
        'title': title,
        'ids': <String, dynamic>{'tmdb': tmdbId},
      },
    };
  }
}

class TraktApiException implements Exception {
  const TraktApiException({
    required this.detail,
    this.statusCode,
  });

  final String detail;
  final int? statusCode;

  factory TraktApiException.fromHttpResponse(
    String raw, {
    required int statusCode,
  }) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return TraktApiException(
          detail: decoded['error_description']?.toString() ??
              decoded['error']?.toString() ??
              decoded['message']?.toString() ??
              'Trakt request failed with status $statusCode.',
          statusCode: statusCode,
        );
      }
    } catch (_) {}
    return TraktApiException(
      detail: 'Trakt request failed with status $statusCode.',
      statusCode: statusCode,
    );
  }

  @override
  String toString() => detail;
}
