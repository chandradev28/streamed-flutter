class PlaylistMovie {
  const PlaylistMovie({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.releaseDate,
  });

  final int id;
  final String title;
  final String? posterPath;
  final String releaseDate;

  factory PlaylistMovie.fromJson(Map<String, dynamic> json) {
    return PlaylistMovie(
      id: json['id'] as int,
      title: (json['title'] as String?) ?? 'Unknown',
      posterPath: json['poster_path'] as String?,
      releaseDate: (json['release_date'] as String?) ?? '',
    );
  }
}
