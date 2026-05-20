import 'dart:convert';

import '../models/torbox_models.dart';
import 'local_json_store.dart';

class AppSettingsRepository {
  AppSettingsRepository({
    LocalJsonStore? store,
  }) : _store = store ?? const LocalJsonStore('.streamed_settings.json');

  final LocalJsonStore _store;

  Future<AppSettings> loadSettings() async {
    final Map<String, dynamic> payload = await _readMap();
    return AppSettings.fromJson(payload);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _writeMap(settings.toJson());
  }

  Future<String?> getTorBoxApiKey() async {
    return (await loadSettings()).torBoxApiKey;
  }

  Future<void> saveTorBoxApiKey(String apiKey) async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(torBoxApiKey: apiKey));
  }

  Future<void> clearTorBoxApiKey() async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(clearApiKey: true));
  }

  Future<DnsProvider> getDnsProvider() async {
    return (await loadSettings()).dnsProvider;
  }

  Future<void> saveDnsProvider(DnsProvider provider) async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(dnsProvider: provider));
  }

  Future<bool> getUseAddons() async {
    return (await loadSettings()).useAddons;
  }

  Future<void> saveUseAddons(bool value) async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(useAddons: value));
  }

  Future<Map<String, dynamic>> _readMap() async {
    final file = await _store.file();
    if (!await file.exists()) {
      return const <String, dynamic>{};
    }

    try {
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const <String, dynamic>{};
      }

      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<void> _writeMap(Map<String, dynamic> payload) async {
    final file = await _store.file();
    await file.writeAsString(jsonEncode(payload));
  }
}
