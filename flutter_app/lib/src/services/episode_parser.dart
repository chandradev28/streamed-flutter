import '../models/torbox_models.dart';

class ParsedEpisodeFile {
  const ParsedEpisodeFile({
    required this.season,
    required this.episode,
    required this.originalIndex,
    required this.title,
  });

  final int season;
  final int episode;
  final int originalIndex;
  final String title;
}

class SeasonFileGroup {
  const SeasonFileGroup({
    required this.season,
    required this.episodes,
  });

  final int season;
  final List<ParsedEpisodeFile> episodes;

  bool get isExtras => season < 0;
}

const List<String> _videoExtensions = <String>[
  '.mkv',
  '.mp4',
  '.avi',
  '.mov',
  '.wmv',
  '.flv',
  '.webm',
  '.m4v',
  '.ts',
  '.m2ts',
];

final List<RegExp> _skipPatterns = <RegExp>[
  RegExp(r'sample', caseSensitive: false),
  RegExp(r'\.srt$', caseSensitive: false),
  RegExp(r'\.sub$', caseSensitive: false),
  RegExp(r'\.ass$', caseSensitive: false),
  RegExp(r'\.vtt$', caseSensitive: false),
  RegExp(r'\.ssa$', caseSensitive: false),
  RegExp(r'\.nfo$', caseSensitive: false),
  RegExp(r'\.txt$', caseSensitive: false),
  RegExp(r'\.jpg$', caseSensitive: false),
  RegExp(r'\.jpeg$', caseSensitive: false),
  RegExp(r'\.png$', caseSensitive: false),
  RegExp(r'featurette', caseSensitive: false),
  RegExp(r'behind\.the\.scenes', caseSensitive: false),
  RegExp(r'deleted\.scenes', caseSensitive: false),
  RegExp(r'extras?[\\/\-\.]', caseSensitive: false),
  RegExp(r'bonus', caseSensitive: false),
  RegExp(r'trailer', caseSensitive: false),
];

bool isValidVideoFile(String filename) {
  final String lower = filename.toLowerCase();
  final bool hasVideoExtension =
      _videoExtensions.any((String ext) => lower.endsWith(ext));
  if (!hasVideoExtension) {
    return false;
  }

  return !_skipPatterns.any((RegExp pattern) => pattern.hasMatch(filename));
}

({int season, int episode})? parseEpisodeInfo(String filename) {
  final String name = _basename(filename);

  final RegExpMatch? match1 =
      RegExp(r'[Ss](\d{1,2})[Ee](\d{1,3})').firstMatch(name);
  if (match1 != null) {
    return (
      season: int.parse(match1.group(1)!),
      episode: int.parse(match1.group(2)!),
    );
  }

  final RegExpMatch? match2 =
      RegExp(r'(\d{1,2})x(\d{1,3})', caseSensitive: false).firstMatch(name);
  if (match2 != null) {
    return (
      season: int.parse(match2.group(1)!),
      episode: int.parse(match2.group(2)!),
    );
  }

  final RegExpMatch? match3 = RegExp(
    r'Season[\s._-]*(\d{1,2})[\s._-]*Episode[\s._-]*(\d{1,3})',
    caseSensitive: false,
  ).firstMatch(name);
  if (match3 != null) {
    return (
      season: int.parse(match3.group(1)!),
      episode: int.parse(match3.group(2)!),
    );
  }

  final RegExpMatch? match4 =
      RegExp(r'[Ee](\d{1,3})(?![xX\d])').firstMatch(name);
  if (match4 != null) {
    return (season: 1, episode: int.parse(match4.group(1)!));
  }

  final RegExpMatch? match5 =
      RegExp(r'[\s._-](\d{2,3})[\s._-]').firstMatch(name);
  if (match5 != null) {
    final int value = int.parse(match5.group(1)!);
    if (value > 0 && value < 100 && value != 19 && value != 20) {
      return (season: 1, episode: value);
    }
  }

  return null;
}

String extractEpisodeTitle(String filename, int season, int episode) {
  final String name = _basename(filename);
  final String withoutExtension = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
  String title = withoutExtension.replaceFirst(
      RegExp(r'^.*?[Ss]\d{1,2}[Ee]\d{1,3}', caseSensitive: false), '');

  title = title
      .replaceAll(RegExp(r'\[.*?\]'), '')
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .replaceAll(RegExp(r'\{.*?\}'), '')
      .replaceAll(
        RegExp(
          r'\b(720p|1080p|2160p|4K|HDR|HEVC|x264|x265|WEB-DL|WEBRip|BluRay|BDRip|HDTV)\b',
          caseSensitive: false,
        ),
        '',
      )
      .replaceFirst(RegExp(r'-[A-Za-z0-9]+$'), '')
      .replaceAll(RegExp(r'[._-]+'), ' ')
      .trim();

  if (title.length > 2 && title.length < 100) {
    return title;
  }

  return 'Episode $episode';
}

List<SeasonFileGroup> parseSeasonPack(List<TorBoxTorrentFile> files) {
  final List<ParsedEpisodeFile> episodes = <ParsedEpisodeFile>[];
  final List<ParsedEpisodeFile> extras = <ParsedEpisodeFile>[];

  for (int index = 0; index < files.length; index += 1) {
    final TorBoxTorrentFile file = files[index];
    if (!isValidVideoFile(file.name)) {
      continue;
    }

    final ({int season, int episode})? info = parseEpisodeInfo(file.name);
    if (info != null) {
      episodes.add(
        ParsedEpisodeFile(
          season: info.season,
          episode: info.episode,
          originalIndex: index,
          title: extractEpisodeTitle(file.name, info.season, info.episode),
        ),
      );
      continue;
    }

    extras.add(
      ParsedEpisodeFile(
        season: -1,
        episode: extras.length + 1,
        originalIndex: index,
        title: _basename(file.name).replaceFirst(RegExp(r'\.[^.]+$'), ''),
      ),
    );
  }

  final Map<int, List<ParsedEpisodeFile>> grouped =
      <int, List<ParsedEpisodeFile>>{};
  for (final ParsedEpisodeFile episode in episodes) {
    grouped
        .putIfAbsent(episode.season, () => <ParsedEpisodeFile>[])
        .add(episode);
  }

  final List<SeasonFileGroup> seasons = grouped.entries
      .map(
        (MapEntry<int, List<ParsedEpisodeFile>> entry) => SeasonFileGroup(
          season: entry.key,
          episodes: (entry.value
                ..sort(
                  (ParsedEpisodeFile a, ParsedEpisodeFile b) =>
                      a.episode.compareTo(b.episode),
                ))
              .toList(growable: false),
        ),
      )
      .toList(growable: true)
    ..sort(
        (SeasonFileGroup a, SeasonFileGroup b) => a.season.compareTo(b.season));

  if (extras.isNotEmpty) {
    seasons.add(SeasonFileGroup(season: -1, episodes: extras));
  }

  return seasons;
}

bool isSeasonPack(List<TorBoxTorrentFile> files) {
  final List<TorBoxTorrentFile> videoFiles = files
      .where((TorBoxTorrentFile file) => isValidVideoFile(file.name))
      .toList(growable: false);
  return videoFiles.length > 1;
}

bool isMovieTorrent(List<TorBoxTorrentFile> files) {
  final List<TorBoxTorrentFile> videoFiles = files
      .where((TorBoxTorrentFile file) => isValidVideoFile(file.name))
      .toList(growable: false);
  if (videoFiles.isEmpty) {
    return false;
  }
  if (videoFiles.length > 5) {
    return false;
  }

  final bool hasEpisodePatterns = videoFiles
      .any((TorBoxTorrentFile file) => parseEpisodeInfo(file.name) != null);
  return !hasEpisodePatterns;
}

List<int> getAllVideoFiles(List<TorBoxTorrentFile> files) {
  final List<int> indices = <int>[];
  for (int index = 0; index < files.length; index += 1) {
    if (isValidVideoFile(files[index].name)) {
      indices.add(index);
    }
  }
  return indices;
}

String formatEpisodeLabel(int season, int episode) {
  return 'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';
}

bool isSeasonPackTitle(String title) {
  if (title.trim().isEmpty) {
    return false;
  }

  final List<RegExp> singleEpisodePatterns = <RegExp>[
    RegExp(r'S\d{1,2}E\d{1,3}', caseSensitive: false),
    RegExp(r'\d{1,2}x\d{1,3}', caseSensitive: false),
    RegExp(r'Episode\s*\d+', caseSensitive: false),
  ];
  if (singleEpisodePatterns.any((RegExp pattern) => pattern.hasMatch(title))) {
    return false;
  }

  final List<RegExp> seasonPackPatterns = <RegExp>[
    RegExp(r'\bS\d{1,2}\b(?!E)', caseSensitive: false),
    RegExp(r'\bSeason\s*\d+\b', caseSensitive: false),
    RegExp(r'\bComplete\b', caseSensitive: false),
    RegExp(r'\bFull\s*Season\b', caseSensitive: false),
    RegExp(r'\bSeasons?\s*\d+\s*[-–]\s*\d+', caseSensitive: false),
    RegExp(r'\bS\d{1,2}\s*[-–]\s*S?\d{1,2}\b', caseSensitive: false),
    RegExp(r'\bEntire\s*Series\b', caseSensitive: false),
    RegExp(r'\bAll\s*Episodes?\b', caseSensitive: false),
  ];

  return seasonPackPatterns.any((RegExp pattern) => pattern.hasMatch(title));
}

String _basename(String value) {
  final List<String> parts = value.split(RegExp(r'[/\\]'));
  return parts.isEmpty ? value : parts.last;
}
