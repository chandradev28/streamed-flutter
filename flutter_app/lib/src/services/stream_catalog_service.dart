import '../models/torbox_models.dart';
import 'real_debrid_api_service.dart';
import 'torbox_api_service.dart';

class StreamCatalogService {
  StreamCatalogService({
    TorBoxApiService? torBoxApiService,
    RealDebridApiService? realDebridApiService,
  })  : torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        realDebridApiService = realDebridApiService ?? RealDebridApiService();

  final TorBoxApiService torBoxApiService;
  final RealDebridApiService realDebridApiService;

  Future<List<StreamSource>> annotateCacheStatus(
    List<StreamSource> streams,
  ) async {
    final List<String> hashes = streams
        .map((StreamSource source) => source.infoHash)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    if (hashes.isEmpty) {
      return streams;
    }

    final Map<String, bool> torBoxCached =
        await _checkTorBoxCachedSafely(hashes);
    final Map<String, bool> realDebridCached =
        await _checkRealDebridCachedSafely(hashes);
    return streams
        .map(
          (StreamSource source) => _markCachedProviders(
            source,
            source.isTorBoxCached || torBoxCached[source.infoHash] == true,
            source.isRealDebridCached ||
                realDebridCached[source.infoHash] == true,
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, bool>> _checkTorBoxCachedSafely(
      List<String> hashes) async {
    try {
      if (!await torBoxApiService.isConfigured()) {
        return const <String, bool>{};
      }
      return torBoxApiService.checkCached(hashes);
    } catch (_) {
      return const <String, bool>{};
    }
  }

  Future<Map<String, bool>> _checkRealDebridCachedSafely(
      List<String> hashes) async {
    try {
      if (!await realDebridApiService.isConfigured()) {
        return const <String, bool>{};
      }
      return realDebridApiService.checkCached(hashes);
    } catch (_) {
      return const <String, bool>{};
    }
  }

  StreamSource _markCachedProviders(
    StreamSource source,
    bool torBoxCached,
    bool realDebridCached,
  ) {
    final List<String> labels = <String>[
      if (torBoxCached) 'TB+',
      if (realDebridCached) 'RD+',
    ];
    return StreamSource(
      id: source.id,
      provider: source.provider,
      sourceDisplayName: source.sourceDisplayName,
      title: source.title,
      description: source.description,
      quality: source.quality,
      sizeLabel: source.sizeLabel,
      isCached: labels.isNotEmpty,
      cacheProvider: labels.isEmpty ? source.cacheProvider : labels.join(' / '),
      addonId: source.addonId,
      infoHash: source.infoHash,
      directUrl: source.directUrl,
      fileIndex: source.fileIndex,
      fileName: source.fileName,
      videoSizeBytes: source.videoSizeBytes,
      magnetUri: source.magnetUri,
      sourceTrackers: source.sourceTrackers,
      streamHeaders: source.streamHeaders,
    );
  }
}
