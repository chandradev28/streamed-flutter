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
      pattern:
          ((json['pattern'] as String?) ?? (json['match'] as String?) ?? '')
              .trim(),
      imageUrl: ((json['imageURL'] as String?) ?? (json['imageUrl'] as String?))
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
    final Iterable<dynamic> rows;
    if (decoded is List<dynamic>) {
      rows = decoded;
    } else if (decoded is Map<String, dynamic>) {
      if (decoded['filters'] is List<dynamic>) {
        rows = decoded['filters'] as List<dynamic>;
      } else if (decoded['badges'] is List<dynamic>) {
        rows = decoded['badges'] as List<dynamic>;
      } else {
        rows = <dynamic>[decoded];
      }
    } else {
      return const <StreamBadge>[];
    }

    return rows
        .whereType<Map<String, dynamic>>()
        .where((Map<String, dynamic> row) => row['isEnabled'] != false)
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
      if (source.cacheProvider != null) source.cacheProvider!,
      if (source.fileName != null) source.fileName!,
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
}
