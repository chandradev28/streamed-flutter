import 'dart:convert';

import '../models/watch_history_item.dart';
import 'local_json_store.dart';

abstract class ContinueWatchingRepository {
  Future<List<WatchHistoryItem>> getContinueWatching([int limit = 20]);
  Future<void> removeFromHistory(String itemId);
  Future<void> saveProgress(WatchHistoryItem item);
}

class WatchHistoryRepository implements ContinueWatchingRepository {
  WatchHistoryRepository({
    LocalJsonStore? store,
  }) : _store = store ?? const LocalJsonStore('.streamed_watch_history.json');

  final LocalJsonStore _store;

  @override
  Future<List<WatchHistoryItem>> getContinueWatching([int limit = 20]) async {
    final List<WatchHistoryItem> history = await _readHistory();
    return history
        .where((WatchHistoryItem item) =>
            item.progress < 95 && item.currentTime > 0)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<void> removeFromHistory(String itemId) async {
    final List<WatchHistoryItem> history = await _readHistory();
    final List<WatchHistoryItem> updated = history
        .where((WatchHistoryItem item) => item.id != itemId)
        .toList(growable: false);
    await _writeHistory(updated);
  }

  @override
  Future<void> saveProgress(WatchHistoryItem item) async {
    final List<WatchHistoryItem> history = await _readHistory();
    final List<WatchHistoryItem> updated = <WatchHistoryItem>[
      item,
      ...history.where((WatchHistoryItem current) => current.id != item.id),
    ];
    await _writeHistory(updated);
  }

  Future<List<WatchHistoryItem>> _readHistory() async {
    final file = await _store.file();
    if (!await file.exists()) {
      return const <WatchHistoryItem>[];
    }

    try {
      final String raw = await file.readAsString();
      if (raw.isEmpty) {
        return const <WatchHistoryItem>[];
      }

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<WatchHistoryItem> items = decoded
          .map(
            (dynamic item) =>
                WatchHistoryItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);

      items.sort(
        (WatchHistoryItem a, WatchHistoryItem b) =>
            b.lastWatched.compareTo(a.lastWatched),
      );

      return items;
    } catch (_) {
      return const <WatchHistoryItem>[];
    }
  }

  Future<void> _writeHistory(List<WatchHistoryItem> items) async {
    final file = await _store.file();
    await file.writeAsString(
      jsonEncode(items.map((WatchHistoryItem item) => item.toJson()).toList()),
    );
  }
}
