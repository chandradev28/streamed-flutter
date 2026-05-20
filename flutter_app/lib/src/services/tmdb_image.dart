String getImageUrl(String? path, [String size = 'w500']) {
  if (path == null || path.isEmpty) {
    return 'https://via.placeholder.com/500x750?text=No+Image';
  }

  return 'https://image.tmdb.org/t/p/$size$path';
}
