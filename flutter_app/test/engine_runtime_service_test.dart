import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/src/models/engine_models.dart';
import 'package:flutter_app/src/services/engine_runtime_service.dart';
import 'package:flutter_app/src/services/engine_storage_service.dart';
import 'package:flutter_app/src/services/engine_yaml_parser.dart';

void main() {
  test('parses Nyaa RSS engine responses', () async {
    final Directory tempDir =
        await Directory.systemTemp.createTemp('streamed_engine_test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final EngineStorageService storage = EngineStorageService(
      directoryProvider: () async => tempDir,
    );
    const EngineYamlParser parser = EngineYamlParser();
    const String nyaaYaml = '''
id: nyaa
display_name: "Nyaa"
capabilities:
  keyword_search: true
  imdb_search: false
  series_support: true
api:
  urls:
    keyword: "https://nyaa.si/"
  params:
    - name: "page"
      value: "rss"
      location: "query"
query_params:
  type: query_params
  param_name: "q"
pagination:
  type: none
response_format:
  type: rss
  results_path: "channel.item"
field_mappings:
  infohash:
    source: "infoHash"
    type: direct
    conversion: lowercase
  name:
    source: "title"
    type: direct
  size_bytes:
    source: "size_bytes"
    type: direct
  seeders:
    source: "seeders"
    type: direct
  leechers:
    source: "leechers"
    type: direct
  category:
    source: "category"
    type: direct
settings:
  - id: enabled
    type: toggle
    label: "Enable Nyaa"
    default: true
''';
    const String rssResponse = '''
<rss version="2.0" xmlns:nyaa="https://nyaa.si/xmlns/nyaa">
  <channel>
    <item>
      <title>Frieren S01E01 1080p</title>
      <category>Anime</category>
      <nyaa:infoHash>ABCDEF1234567890</nyaa:infoHash>
      <nyaa:size>1.4 GiB</nyaa:size>
      <nyaa:seeders>89</nyaa:seeders>
      <nyaa:leechers>7</nyaa:leechers>
    </item>
  </channel>
</rss>
''';

    final ParsedEngineConfig parsed = parser.parse(
      nyaaYaml,
      fileName: 'nyaa.yaml',
    );
    await storage.saveImportedEngine(
      engine: parsed.toImportedEngine('nyaa.yaml'),
      yamlContent: nyaaYaml,
    );

    final EngineRuntimeService runtime = EngineRuntimeService(
      storageService: storage,
      requestExecutor: (_) async => rssResponse,
    );

    final KeywordEngineSearchResult result =
        await runtime.searchKeyword('frieren');

    expect(result.streams, hasLength(1));
    expect(result.diagnostics.sourceCounts['Nyaa'], 1);
    expect(result.diagnostics.sourceErrors, isEmpty);

    final source = result.streams.single;
    expect(source.sourceDisplayName, 'Nyaa');
    expect(source.infoHash, 'abcdef1234567890');
    expect(source.title, contains('Frieren'));
    expect(source.sizeLabel, contains('GB'));
    expect(source.description, contains('Seeders 89'));
  });
}
