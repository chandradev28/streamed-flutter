class RemoteEngineInfo {
  const RemoteEngineInfo({
    required this.id,
    required this.fileName,
    required this.displayName,
    this.description,
    this.icon,
    this.keywordSearch = false,
    this.imdbSearch = false,
    this.seriesSupport = false,
    this.responseFormat = 'unknown',
    this.supportedInApp = false,
    this.defaultMaxResults = 50,
    this.maxResultOptions = const <int>[25, 50, 100],
  });

  final String id;
  final String fileName;
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
}

class ImportedEngine {
  const ImportedEngine({
    required this.id,
    required this.fileName,
    required this.displayName,
    required this.importedAt,
    required this.enabled,
    required this.maxResults,
    required this.keywordSearch,
    required this.imdbSearch,
    required this.seriesSupport,
    required this.responseFormat,
    required this.supportedInApp,
    this.description,
    this.icon,
    this.maxResultOptions = const <int>[25, 50, 100],
  });

  final String id;
  final String fileName;
  final String displayName;
  final String? description;
  final String? icon;
  final DateTime importedAt;
  final bool enabled;
  final int maxResults;
  final bool keywordSearch;
  final bool imdbSearch;
  final bool seriesSupport;
  final String responseFormat;
  final bool supportedInApp;
  final List<int> maxResultOptions;

  ImportedEngine copyWith({
    String? fileName,
    String? displayName,
    String? description,
    String? icon,
    DateTime? importedAt,
    bool? enabled,
    int? maxResults,
    bool? keywordSearch,
    bool? imdbSearch,
    bool? seriesSupport,
    String? responseFormat,
    bool? supportedInApp,
    List<int>? maxResultOptions,
  }) {
    return ImportedEngine(
      id: id,
      fileName: fileName ?? this.fileName,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      importedAt: importedAt ?? this.importedAt,
      enabled: enabled ?? this.enabled,
      maxResults: maxResults ?? this.maxResults,
      keywordSearch: keywordSearch ?? this.keywordSearch,
      imdbSearch: imdbSearch ?? this.imdbSearch,
      seriesSupport: seriesSupport ?? this.seriesSupport,
      responseFormat: responseFormat ?? this.responseFormat,
      supportedInApp: supportedInApp ?? this.supportedInApp,
      maxResultOptions: maxResultOptions ?? this.maxResultOptions,
    );
  }

  factory ImportedEngine.fromJson(Map<String, dynamic> json) {
    return ImportedEngine(
      id: (json['id'] as String?) ?? '',
      fileName: (json['fileName'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? 'Unknown engine',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      importedAt: DateTime.tryParse(json['importedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      enabled: json['enabled'] as bool? ?? true,
      maxResults: (json['maxResults'] as num?)?.toInt() ?? 50,
      keywordSearch: json['keywordSearch'] as bool? ?? false,
      imdbSearch: json['imdbSearch'] as bool? ?? false,
      seriesSupport: json['seriesSupport'] as bool? ?? false,
      responseFormat: (json['responseFormat'] as String?) ?? 'unknown',
      supportedInApp: json['supportedInApp'] as bool? ?? false,
      maxResultOptions:
          ((json['maxResultOptions'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic value) => (value as num).toInt())
              .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'fileName': fileName,
      'displayName': displayName,
      'description': description,
      'icon': icon,
      'importedAt': importedAt.toIso8601String(),
      'enabled': enabled,
      'maxResults': maxResults,
      'keywordSearch': keywordSearch,
      'imdbSearch': imdbSearch,
      'seriesSupport': seriesSupport,
      'responseFormat': responseFormat,
      'supportedInApp': supportedInApp,
      'maxResultOptions': maxResultOptions,
    };
  }
}
