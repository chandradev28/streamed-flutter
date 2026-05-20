import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/engine_models.dart';

typedef EngineDirectoryProvider = Future<Directory> Function();

class EngineStorageService {
  EngineStorageService({
    EngineDirectoryProvider? directoryProvider,
  }) : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  static const String _folderName = 'streamed_engines';
  static const String _metadataFileName = 'metadata.json';

  final EngineDirectoryProvider _directoryProvider;

  Directory? _cachedDirectory;

  Future<List<ImportedEngine>> getImportedEngines() async {
    final Map<String, dynamic> payload = await _readMetadata();
    final List<dynamic> rows =
        payload['engines'] as List<dynamic>? ?? const <dynamic>[];
    final List<ImportedEngine> engines = rows
        .map((dynamic row) =>
            ImportedEngine.fromJson(row as Map<String, dynamic>))
        .toList(growable: false)
      ..sort(
        (ImportedEngine a, ImportedEngine b) =>
            a.displayName.compareTo(b.displayName),
      );
    return engines;
  }

  Future<void> saveImportedEngine({
    required ImportedEngine engine,
    required String yamlContent,
  }) async {
    final List<ImportedEngine> current = await getImportedEngines();
    final List<ImportedEngine> next = current
        .where((ImportedEngine item) => item.id != engine.id)
        .toList(growable: true)
      ..add(engine);

    final Directory directory = await _getDirectory();
    final File yamlFile =
        File('${directory.path}${Platform.pathSeparator}${engine.fileName}');
    await yamlFile.writeAsString(yamlContent);
    await _writeMetadata(next);
  }

  Future<void> updateImportedEngine(ImportedEngine engine) async {
    final List<ImportedEngine> current = await getImportedEngines();
    final List<ImportedEngine> next = current
        .where((ImportedEngine item) => item.id != engine.id)
        .toList(growable: true)
      ..add(engine);
    await _writeMetadata(next);
  }

  Future<void> deleteImportedEngine(String engineId) async {
    final List<ImportedEngine> current = await getImportedEngines();
    final ImportedEngine? target = current.cast<ImportedEngine?>().firstWhere(
          (ImportedEngine? item) => item?.id == engineId,
          orElse: () => null,
        );
    if (target == null) {
      return;
    }

    final Directory directory = await _getDirectory();
    final File yamlFile =
        File('${directory.path}${Platform.pathSeparator}${target.fileName}');
    if (await yamlFile.exists()) {
      await yamlFile.delete();
    }

    final List<ImportedEngine> next = current
        .where((ImportedEngine item) => item.id != engineId)
        .toList(growable: false);
    await _writeMetadata(next);
  }

  Future<String?> readEngineYaml(String engineId) async {
    final List<ImportedEngine> engines = await getImportedEngines();
    final ImportedEngine? target = engines.cast<ImportedEngine?>().firstWhere(
          (ImportedEngine? item) => item?.id == engineId,
          orElse: () => null,
        );
    if (target == null) {
      return null;
    }

    final Directory directory = await _getDirectory();
    final File yamlFile =
        File('${directory.path}${Platform.pathSeparator}${target.fileName}');
    if (!await yamlFile.exists()) {
      return null;
    }
    return yamlFile.readAsString();
  }

  Future<Directory> _getDirectory() async {
    if (_cachedDirectory != null) {
      return _cachedDirectory!;
    }

    final Directory base = await _directoryProvider();
    final Directory directory =
        Directory('${base.path}${Platform.pathSeparator}$_folderName');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _cachedDirectory = directory;
    return directory;
  }

  Future<Map<String, dynamic>> _readMetadata() async {
    final File file = await _metadataFile();
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

  Future<void> _writeMetadata(List<ImportedEngine> engines) async {
    final File file = await _metadataFile();
    final List<Map<String, dynamic>> rows = engines
        .map((ImportedEngine engine) => engine.toJson())
        .toList()
      ..sort(
        (Map<String, dynamic> a, Map<String, dynamic> b) =>
            (a['displayName'] as String).compareTo(b['displayName'] as String),
      );
    await file.writeAsString(
      jsonEncode(
        <String, dynamic>{
          'updatedAt': DateTime.now().toIso8601String(),
          'engines': rows,
        },
      ),
    );
  }

  Future<File> _metadataFile() async {
    final Directory directory = await _getDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_metadataFileName');
  }
}
