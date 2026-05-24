import 'dart:convert';

import '../models/torbox_models.dart';
import 'local_json_store.dart';

class MagnetHistoryRepository {
  MagnetHistoryRepository({
    LocalJsonStore? store,
  }) : _store = store ?? const LocalJsonStore('.streamed_magnet_history.json');

  final LocalJsonStore _store;

  Future<List<MagnetHistoryItem>> getHistory() async {
    final file = await _store.file();
    if (!await file.exists()) {
      return const <MagnetHistoryItem>[];
    }

    try {
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const <MagnetHistoryItem>[];
      }

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) =>
                MagnetHistoryItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } catch (_) {
      return const <MagnetHistoryItem>[];
    }
  }

  Future<Set<String>> getHashes() async {
    final List<MagnetHistoryItem> items = await getHistory();
    return items
        .map((MagnetHistoryItem item) => item.hash.toLowerCase())
        .toSet();
  }

  Future<void> addHashes(Iterable<String> hashes) async {
    final Map<String, MagnetHistoryItem> merged = <String, MagnetHistoryItem>{};

    for (final MagnetHistoryItem item in await getHistory()) {
      merged[item.hash.toLowerCase()] = item;
    }

    for (final String hash in hashes) {
      final String normalized = hash.toLowerCase();
      merged.putIfAbsent(
        normalized,
        () => MagnetHistoryItem(
          hash: normalized,
          addedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    await _saveItems(merged.values.toList(growable: false));
  }

  Future<void> removeHash(String hash) async {
    final String normalized = hash.toLowerCase();
    final List<MagnetHistoryItem> items = await getHistory();
    final List<MagnetHistoryItem> updated = items
        .where(
            (MagnetHistoryItem item) => item.hash.toLowerCase() != normalized)
        .toList(growable: false);
    await _saveItems(updated);
  }

  Future<void> _saveItems(List<MagnetHistoryItem> items) async {
    final file = await _store.file();
    await file.writeAsString(
      jsonEncode(
        items.map((MagnetHistoryItem item) => item.toJson()).toList(),
      ),
    );
  }
}
