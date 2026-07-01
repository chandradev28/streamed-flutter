import 'dart:convert';

import '../models/torbox_models.dart';

class StreamBadge {
  const StreamBadge({
    required this.name,
    required this.pattern,
    this.imageUrl,
    this.tagColor,
    this.borderColor,
    this.textColor,
  });

  final String name;
  final String pattern;
  final String? imageUrl;
  final String? tagColor;
  final String? borderColor;
  final String? textColor;

  factory StreamBadge.fromJson(Map<String, dynamic> json) {
    return StreamBadge(
      name: (json['name'] as String?)?.trim() ?? 'Badge',
      pattern: ((json['pattern'] as String?) ??
              (json['match'] as String?) ??
              (json['regex'] as String?) ??
              '')
          .trim(),
      imageUrl: ((json['imageURL'] as String?) ??
              (json['imageUrl'] as String?) ??
              (json['image'] as String?) ??
              (json['image_url'] as String?))
          ?.trim(),
      tagColor: (json['tagColor'] as String?)?.trim(),
      borderColor: (json['borderColor'] as String?)?.trim(),
      textColor: (json['textColor'] as String?)?.trim(),
    );
  }
}

class StreamBadgeService {
  const StreamBadgeService();

  List<StreamBadge> parseBadges(String rawJson) {
    final String trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const <StreamBadge>[];
    }

    final dynamic decoded = jsonDecode(trimmed);
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    _collectBadgeRows(decoded, rows);
    if (rows.isEmpty) {
      return const <StreamBadge>[];
    }

    return rows
        .where(_isEnabled)
        .map(StreamBadge.fromJson)
        .where(
          (StreamBadge badge) =>
              badge.name.trim().isNotEmpty && badge.pattern.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  List<StreamBadge> matchesForSource({
    required List<StreamBadge> badges,
    required StreamSource source,
    int limit = 14,
  }) {
    if (badges.isEmpty) {
      return const <StreamBadge>[];
    }

    final String searchable = <String>[
      source.title,
      source.description,
      source.quality,
      source.sizeLabel,
      source.sourceDisplayName,
      _qualityAliases(source.quality),
      _qualityAliases(source.title),
      _qualityAliases(source.description),
      if (source.cacheProvider != null) source.cacheProvider!,
      if (source.fileName != null) source.fileName!,
      if (source.videoSizeBytes != null) '${source.videoSizeBytes}',
    ].join('\n');

    final List<StreamBadge> matches = <StreamBadge>[];
    for (final StreamBadge badge in badges) {
      if (_matches(badge, searchable)) {
        matches.add(badge);
      }
      if (matches.length >= limit) {
        break;
      }
    }
    return matches;
  }

  bool _matches(StreamBadge badge, String searchable) {
    try {
      return RegExp(badge.pattern, caseSensitive: false, multiLine: true)
          .hasMatch(searchable);
    } catch (_) {
      final String needle = badge.pattern.toLowerCase().trim();
      return needle.isNotEmpty && searchable.toLowerCase().contains(needle);
    }
  }

  void _collectBadgeRows(dynamic value, List<Map<String, dynamic>> rows) {
    if (value is List<dynamic>) {
      for (final dynamic item in value) {
        _collectBadgeRows(item, rows);
      }
      return;
    }

    if (value is! Map<String, dynamic>) {
      return;
    }

    if (_looksLikeBadge(value)) {
      rows.add(value);
    }

    for (final String key in <String>[
      'filters',
      'badges',
      'items',
      'children',
      'groups',
      'categories',
      'templates',
    ]) {
      if (value.containsKey(key)) {
        _collectBadgeRows(value[key], rows);
      }
    }
  }

  bool _looksLikeBadge(Map<String, dynamic> row) {
    return row.containsKey('pattern') ||
        row.containsKey('match') ||
        row.containsKey('regex') ||
        row.containsKey('imageURL') ||
        row.containsKey('imageUrl') ||
        row.containsKey('image') ||
        row.containsKey('image_url');
  }

  bool _isEnabled(Map<String, dynamic> row) {
    if (_isFalse(row['isEnabled']) ||
        _isFalse(row['enabled']) ||
        _isFalse(row['use']) ||
        _isTrue(row['disabled'])) {
      return false;
    }
    return true;
  }

  bool _isFalse(dynamic value) {
    if (value == false) {
      return true;
    }
    return value?.toString().trim().toLowerCase() == 'false';
  }

  bool _isTrue(dynamic value) {
    if (value == true) {
      return true;
    }
    return value?.toString().trim().toLowerCase() == 'true';
  }

  String _qualityAliases(String raw) {
    final String text = raw.toLowerCase();
    final Set<String> aliases = <String>{};
    if (text.contains('4k') || text.contains('2160')) {
      aliases.addAll(<String>['4k', 'uhd', '2160p', '2160']);
    }
    if (text.contains('1080')) {
      aliases.addAll(<String>['1080p', '1080', 'fhd']);
    }
    if (text.contains('720')) {
      aliases.addAll(<String>['720p', '720', 'hd']);
    }
    if (text.contains('480')) {
      aliases.addAll(<String>['480p', '480', 'sd']);
    }
    return aliases.join('\n');
  }
}
