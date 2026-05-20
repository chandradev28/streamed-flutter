import 'dart:convert';

import '../models/favorite_item.dart';
import 'local_json_store.dart';

class FavoritesRepository {
  FavoritesRepository({
    LocalJsonStore? store,
  }) : _store = store ?? const LocalJsonStore('.streamed_favorites.json');

  final LocalJsonStore _store;

  Future<List<FavoriteItem>> getFavorites() async {
    final file = await _store.file();
    if (!await file.exists()) {
      return const <FavoriteItem>[];
    }

    try {
      final String raw = await file.readAsString();
      if (raw.isEmpty) {
        return const <FavoriteItem>[];
      }

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<FavoriteItem> favorites = decoded
          .map(
            (item) => FavoriteItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);

      favorites.sort(
        (FavoriteItem a, FavoriteItem b) => b.addedAt.compareTo(a.addedAt),
      );

      return favorites;
    } catch (_) {
      return const <FavoriteItem>[];
    }
  }

  Future<void> removeFromFavorites(int id, String mediaType) async {
    final List<FavoriteItem> favorites = await getFavorites();
    final List<FavoriteItem> updated = favorites
        .where(
          (item) => item.id != id || item.mediaType != mediaType,
        )
        .toList(growable: false);

    await _writeFavorites(updated);
  }

  Future<bool> isFavorite(int id, String mediaType) async {
    final List<FavoriteItem> favorites = await getFavorites();
    return favorites.any(
      (FavoriteItem item) => item.id == id && item.mediaType == mediaType,
    );
  }

  Future<void> addToFavorites(FavoriteItem item) async {
    final List<FavoriteItem> favorites = await getFavorites();
    final bool exists = favorites.any(
      (FavoriteItem favorite) =>
          favorite.id == item.id && favorite.mediaType == item.mediaType,
    );
    if (exists) {
      return;
    }

    final List<FavoriteItem> updated = <FavoriteItem>[item, ...favorites];
    await _writeFavorites(updated);
  }

  Future<bool> toggleFavorite(FavoriteItem item) async {
    if (await isFavorite(item.id, item.mediaType)) {
      await removeFromFavorites(item.id, item.mediaType);
      return false;
    }

    await addToFavorites(item);
    return true;
  }

  Future<void> _writeFavorites(List<FavoriteItem> items) async {
    final file = await _store.file();
    await file.writeAsString(
      jsonEncode(
        items.map((FavoriteItem item) => item.toJson()).toList(growable: false),
      ),
    );
  }
}
