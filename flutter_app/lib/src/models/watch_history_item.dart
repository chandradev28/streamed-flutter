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
    this.seasonNumber,
    this.episodeNumber,
    this.episodeName,
  });

  final String id;
  final int tmdbId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;
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
      seasonNumber: json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int?,
      episodeName: json['episodeName'] as String?,
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
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'episodeName': episodeName,
      'progress': progress,
      'currentTime': currentTime,
      'duration': duration,
      'lastWatched': lastWatched,
      'addedAt': addedAt,
    };
  }
}
