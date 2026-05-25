import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/torbox_models.dart';
import 'local_json_store.dart';

class AppSettingsRepository {
  AppSettingsRepository({
    LocalJsonStore? store,
  }) : _store = store ?? const LocalJsonStore('.streamed_settings.json');

  final LocalJsonStore _store;

  static final ValueNotifier<AppSettings> settingsNotifier =
      ValueNotifier<AppSettings>(const AppSettings());

  Future<AppSettings> loadSettings() async {
    final Map<String, dynamic> payload = await _readMap();
    final AppSettings settings = AppSettings.fromJson(payload);
    settingsNotifier.value = settings;
    return settings;
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _writeMap(settings.toJson());
    settingsNotifier.value = settings;
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

  Future<String?> getRealDebridApiKey() async {
    return (await loadSettings()).realDebridApiKey;
  }

  Future<void> saveRealDebridApiKey(String apiKey) async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(realDebridApiKey: apiKey));
  }

  Future<void> clearRealDebridApiKey() async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(clearRealDebridApiKey: true));
  }

  Future<String> getPreferredDebridProvider() async {
    return (await loadSettings()).preferredDebridProvider;
  }

  Future<void> savePreferredDebridProvider(String provider) async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(preferredDebridProvider: provider));
  }

  Future<bool> getUseAddons() async {
    return (await loadSettings()).useAddons;
  }

  Future<void> saveUseAddons(bool value) async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(useAddons: value));
  }

  Future<bool> getCloudLibraryEnabled() async {
    return (await loadSettings()).cloudLibraryEnabled;
  }

  Future<void> saveCloudLibraryEnabled(bool value) async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(cloudLibraryEnabled: value));
  }

  Future<bool> getResolvePlayableLinksEnabled() async {
    return (await loadSettings()).resolvePlayableLinksEnabled;
  }

  Future<void> saveResolvePlayableLinksEnabled(bool value) async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(resolvePlayableLinksEnabled: value));
  }

  Future<void> saveTmdbApiKey(String apiKey) async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(tmdbApiKey: apiKey));
  }

  Future<void> clearTmdbApiKey() async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(clearTmdbApiKey: true));
  }

  Future<void> saveMdbListApiKey(String apiKey) async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(mdbListApiKey: apiKey));
  }

  Future<void> clearMdbListApiKey() async {
    final AppSettings settings = await loadSettings();
    await saveSettings(settings.copyWith(clearMdbListApiKey: true));
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
