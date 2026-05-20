import 'package:yaml/yaml.dart';

import '../models/engine_models.dart';

class ParsedEngineConfig {
  const ParsedEngineConfig({
    required this.id,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.keywordSearch,
    required this.imdbSearch,
    required this.seriesSupport,
    required this.responseFormat,
    required this.supportedInApp,
    required this.defaultMaxResults,
    required this.maxResultOptions,
    required this.document,
  });

  final String id;
  final String displayName;
  final String? description;
  final String? icon;
  final bool keywordSearch;
  final bool imdbSearch;
  final bool seriesSupport;
  final String responseFormat;
  final bool supportedInApp;
  final int defaultMaxResults;
  final List<int> maxResultOptions;
  final Map<String, dynamic> document;

  RemoteEngineInfo toRemoteInfo(String fileName) {
    return RemoteEngineInfo(
      id: id,
      fileName: fileName,
      displayName: displayName,
      description: description,
      icon: icon,
      keywordSearch: keywordSearch,
      imdbSearch: imdbSearch,
      seriesSupport: seriesSupport,
      responseFormat: responseFormat,
      supportedInApp: supportedInApp,
      defaultMaxResults: defaultMaxResults,
      maxResultOptions: maxResultOptions,
    );
  }

  ImportedEngine toImportedEngine(String fileName) {
    return ImportedEngine(
      id: id,
      fileName: fileName,
      displayName: displayName,
      description: description,
      icon: icon,
      importedAt: DateTime.now(),
      enabled: true,
      maxResults: defaultMaxResults,
      keywordSearch: keywordSearch,
      imdbSearch: imdbSearch,
      seriesSupport: seriesSupport,
      responseFormat: responseFormat,
      supportedInApp: supportedInApp,
      maxResultOptions: maxResultOptions,
    );
  }
}

class EngineYamlParser {
  const EngineYamlParser();

  ParsedEngineConfig parse(String rawYaml, {required String fileName}) {
    final dynamic loaded = loadYaml(rawYaml);
    final Map<String, dynamic> document = _toMap(loaded);
    final Map<String, dynamic> capabilities = _asMap(document['capabilities']);
    final List<Map<String, dynamic>> settings =
        _asList(document['settings']).map(_asMap).toList(growable: false);
    final String responseFormat =
        (_asMap(document['response_format'])['type'] as String? ?? 'unknown')
            .trim();
    final String id =
        (document['id'] as String?) ?? fileName.replaceAll('.yaml', '').trim();
    final int defaultMaxResults = _readDefaultMaxResults(settings);
    final List<int> maxResultOptions = _readMaxResultOptions(
      settings,
      fallback: defaultMaxResults,
    );

    return ParsedEngineConfig(
      id: id,
      displayName: (document['display_name'] as String?) ?? _toTitleCase(id),
      description: document['description'] as String?,
      icon: document['icon'] as String?,
      keywordSearch: capabilities['keyword_search'] as bool? ?? false,
      imdbSearch: capabilities['imdb_search'] as bool? ?? false,
      seriesSupport: capabilities['series_support'] as bool? ?? false,
      responseFormat: responseFormat,
      supportedInApp: _supportsInApp(responseFormat),
      defaultMaxResults: defaultMaxResults,
      maxResultOptions: maxResultOptions,
      document: document,
    );
  }

  Map<String, dynamic> _toMap(dynamic input) {
    if (input is YamlMap) {
      return input.map(
        (dynamic key, dynamic value) =>
            MapEntry(key.toString(), _normalize(value)),
      );
    }
    if (input is Map<dynamic, dynamic>) {
      return input.map(
        (dynamic key, dynamic value) =>
            MapEntry(key.toString(), _normalize(value)),
      );
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is YamlList) {
      return value.map(_normalize).toList(growable: false);
    }
    if (value is List<dynamic>) {
      return value.map(_normalize).toList(growable: false);
    }
    return const <dynamic>[];
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    return _toMap(value);
  }

  dynamic _normalize(dynamic value) {
    if (value is YamlMap || value is Map<dynamic, dynamic>) {
      return _toMap(value);
    }
    if (value is YamlList || value is List<dynamic>) {
      return _asList(value);
    }
    return value;
  }

  int _readDefaultMaxResults(List<Map<String, dynamic>> settings) {
    for (final Map<String, dynamic> setting in settings) {
      if (setting['id'] == 'max_results') {
        return (setting['default'] as num?)?.toInt() ?? 50;
      }
    }
    return 50;
  }

  List<int> _readMaxResultOptions(
    List<Map<String, dynamic>> settings, {
    required int fallback,
  }) {
    for (final Map<String, dynamic> setting in settings) {
      if (setting['id'] == 'max_results') {
        final List<int> values = _asList(setting['options'])
            .map((dynamic item) {
              if (item is num) {
                return item.toInt();
              }
              return int.tryParse(item.toString()) ?? fallback;
            })
            .toSet()
            .toList()
          ..sort();
        if (values.isNotEmpty) {
          return values;
        }
      }
    }
    return <int>{25, fallback, 100}.toList()..sort();
  }

  bool _supportsInApp(String responseFormat) {
    switch (responseFormat) {
      case 'direct_json':
      case 'json':
      case 'jina_wrapped':
      case 'rss':
        return true;
      default:
        return false;
    }
  }

  String _toTitleCase(String value) {
    return value
        .split('_')
        .where((String segment) => segment.isNotEmpty)
        .map(
          (String segment) =>
              '${segment[0].toUpperCase()}${segment.substring(1)}',
        )
        .join(' ');
  }
}
