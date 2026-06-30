String getImageUrl(String? path, [String size = 'w500']) {
  if (path == null || path.isEmpty) {
    return 'https://via.placeholder.com/500x750?text=No+Image';
  }

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }

  return 'https://image.tmdb.org/t/p/$size$path';
}
