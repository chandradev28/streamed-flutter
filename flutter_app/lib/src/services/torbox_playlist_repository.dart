import 'dart:convert';

import '../models/torbox_models.dart';
import 'local_json_store.dart';

class TorboxPlaylistRepository {
  TorboxPlaylistRepository({
    LocalJsonStore? store,
  }) : _store = store ?? const LocalJsonStore('.streamed_torbox_playlist.json');

  final LocalJsonStore _store;

  Future<List<StreamSource>> getItems() async {
    final file = await _store.file();
    if (!await file.exists()) {
      return const <StreamSource>[];
    }

    try {
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const <StreamSource>[];
      }

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) => StreamSource.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    } catch (_) {
      return const <StreamSource>[];
    }
  }

  Future<void> addItem(StreamSource item) async {
    final List<StreamSource> items = await getItems();
    final bool exists = items.any((StreamSource current) => current.id == item.id);
    if (exists) {
      return;
    }

    await _writeItems(<StreamSource>[item, ...items]);
  }

  Future<void> removeItem(String id) async {
    final List<StreamSource> items = await getItems();
    await _writeItems(
      items.where((StreamSource item) => item.id != id).toList(growable: false),
    );
  }

  Future<void> _writeItems(List<StreamSource> items) async {
    final file = await _store.file();
    await file.writeAsString(
      jsonEncode(items.map((StreamSource item) => item.toJson()).toList()),
    );
  }
}
