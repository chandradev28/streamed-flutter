class WatchHistoryItem {
  const WatchHistoryItem({
    required this.id,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    required this.progress,
    required this.currentTime,
    required this.duration,
    required this.lastWatched,
    required this.addedAt,
    this.backdropPath,
    this.imdbId,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeName,
    this.provider,
    this.resolvedUrl,
    this.streamHeaders,
    this.torrentHash,
    this.torrentId,
    this.activeFileId,
    this.activeFileIndex,
    this.activeFileName,
  });

  final String id;
  final int tmdbId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? imdbId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;
  final String? provider;
  final String? resolvedUrl;
  final Map<String, String>? streamHeaders;
  final String? torrentHash;
  final int? torrentId;
  final int? activeFileId;
  final int? activeFileIndex;
  final String? activeFileName;
  final double progress;
  final int currentTime;
  final int duration;
  final int lastWatched;
  final int addedAt;

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return WatchHistoryItem(
      id: json['id'] as String,
      tmdbId: json['tmdbId'] as int,
      mediaType: json['mediaType'] as String,
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      imdbId: json['imdbId'] as String?,
      seasonNumber: json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int?,
      episodeName: json['episodeName'] as String?,
      provider: json['provider'] as String?,
      resolvedUrl: json['resolvedUrl'] as String?,
      streamHeaders: (json['streamHeaders'] as Map<dynamic, dynamic>?)?.map(
        (dynamic key, dynamic value) => MapEntry(
          key.toString(),
          value.toString(),
        ),
      ),
      torrentHash: json['torrentHash'] as String?,
      torrentId: (json['torrentId'] as num?)?.toInt(),
      activeFileId: (json['activeFileId'] as num?)?.toInt(),
      activeFileIndex: (json['activeFileIndex'] as num?)?.toInt(),
      activeFileName: json['activeFileName'] as String?,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      currentTime: (json['currentTime'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      lastWatched: (json['lastWatched'] as num?)?.toInt() ?? 0,
      addedAt: (json['addedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'tmdbId': tmdbId,
      'mediaType': mediaType,
      'title': title,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'imdbId': imdbId,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'episodeName': episodeName,
      'provider': provider,
      'resolvedUrl': resolvedUrl,
      'streamHeaders': streamHeaders,
      'torrentHash': torrentHash,
      'torrentId': torrentId,
      'activeFileId': activeFileId,
      'activeFileIndex': activeFileIndex,
      'activeFileName': activeFileName,
      'progress': progress,
      'currentTime': currentTime,
      'duration': duration,
      'lastWatched': lastWatched,
      'addedAt': addedAt,
    };
  }
}
