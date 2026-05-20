class FavoriteItem {
  const FavoriteItem({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    required this.addedAt,
    this.backdropPath,
    this.rating,
    this.year,
  });

  final int id;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final double? rating;
  final String? year;
  final int addedAt;

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as int,
      mediaType: json['mediaType'] as String,
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      year: json['year'] as String?,
      addedAt: json['addedAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'mediaType': mediaType,
      'title': title,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'rating': rating,
      'year': year,
      'addedAt': addedAt,
    };
  }
}
