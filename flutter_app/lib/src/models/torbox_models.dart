class AppSettings {
  const AppSettings({
    this.torBoxApiKey,
    this.dnsProvider = DnsProvider.none,
    this.useAddons = false,
  });

  final String? torBoxApiKey;
  final DnsProvider dnsProvider;
  final bool useAddons;

  AppSettings copyWith({
    String? torBoxApiKey,
    bool clearApiKey = false,
    DnsProvider? dnsProvider,
    bool? useAddons,
  }) {
    return AppSettings(
      torBoxApiKey: clearApiKey ? null : (torBoxApiKey ?? this.torBoxApiKey),
      dnsProvider: dnsProvider ?? this.dnsProvider,
      useAddons: useAddons ?? this.useAddons,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      torBoxApiKey: json['torBoxApiKey'] as String?,
      dnsProvider: DnsProviderX.fromStorage(json['dnsProvider'] as String?),
      useAddons: json['useAddons'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'torBoxApiKey': torBoxApiKey,
      'dnsProvider': dnsProvider.storageValue,
      'useAddons': useAddons,
    };
  }
}

enum DnsProvider {
  none,
  cloudflare,
  google,
  adguard,
  quad9,
}

extension DnsProviderX on DnsProvider {
  String get storageValue {
    switch (this) {
      case DnsProvider.none:
        return 'none';
      case DnsProvider.cloudflare:
        return 'cloudflare';
      case DnsProvider.google:
        return 'google';
      case DnsProvider.adguard:
        return 'adguard';
      case DnsProvider.quad9:
        return 'quad9';
    }
  }

  String get label {
    switch (this) {
      case DnsProvider.none:
        return 'System DNS';
      case DnsProvider.cloudflare:
        return 'Cloudflare';
      case DnsProvider.google:
        return 'Google';
      case DnsProvider.adguard:
        return 'AdGuard';
      case DnsProvider.quad9:
        return 'Quad9';
    }
  }

  static DnsProvider fromStorage(String? value) {
    return DnsProvider.values.firstWhere(
      (DnsProvider provider) => provider.storageValue == value,
      orElse: () => DnsProvider.none,
    );
  }
}

class TorBoxUser {
  const TorBoxUser({
    required this.email,
    required this.plan,
    required this.createdAt,
    required this.totalSlots,
    required this.usedSlots,
    this.premiumExpiresAt,
  });

  final String email;
  final String plan;
  final String? createdAt;
  final int totalSlots;
  final int usedSlots;
  final String? premiumExpiresAt;

  factory TorBoxUser.fromJson(Map<String, dynamic> json) {
    return TorBoxUser(
      email: (json['email'] as String?) ??
          (json['username'] as String?) ??
          'TorBox account',
      plan: (json['plan'] as String?) ??
          (json['subscription'] as String?) ??
          'Unknown plan',
      createdAt: json['created_at'] as String?,
      totalSlots: (json['total_slots'] as num?)?.toInt() ??
          (json['slots'] as num?)?.toInt() ??
          0,
      usedSlots: (json['used_slots'] as num?)?.toInt() ??
          (json['active_downloads'] as num?)?.toInt() ??
          0,
      premiumExpiresAt: json['premium_expires_at'] as String? ??
          json['premium_expiration'] as String?,
    );
  }
}

class TorBoxTorrentFile {
  const TorBoxTorrentFile({
    required this.id,
    required this.name,
    required this.size,
    this.shortName,
  });

  final int id;
  final String name;
  final int size;
  final String? shortName;

  String get displayName {
    if (shortName != null && shortName!.trim().isNotEmpty) {
      return shortName!;
    }

    final List<String> parts = name.split('/');
    return parts.isEmpty ? name : parts.last;
  }

  factory TorBoxTorrentFile.fromJson(Map<String, dynamic> json) {
    return TorBoxTorrentFile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? 'Unknown file',
      size: (json['size'] as num?)?.toInt() ?? 0,
      shortName: json['short_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'size': size,
      'short_name': shortName,
    };
  }
}

class TorBoxTorrent {
  const TorBoxTorrent({
    required this.id,
    required this.hash,
    required this.name,
    required this.size,
    required this.downloadState,
    required this.downloadSpeed,
    required this.progress,
    required this.files,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String hash;
  final String name;
  final int size;
  final String downloadState;
  final int downloadSpeed;
  final double progress;
  final List<TorBoxTorrentFile> files;
  final String? createdAt;
  final String? updatedAt;

  bool get isReady => progress >= 100;

  factory TorBoxTorrent.fromJson(Map<String, dynamic> json) {
    final double primaryProgress = (json['progress'] as num?)?.toDouble() ?? -1;
    final double secondaryProgress =
        (json['download_progress'] as num?)?.toDouble() ?? 0;
    final double rawProgress =
        primaryProgress >= 0 ? primaryProgress : secondaryProgress;

    return TorBoxTorrent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      hash: (json['hash'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Unknown torrent',
      size: (json['size'] as num?)?.toInt() ?? 0,
      downloadState: (json['download_state'] as String?) ?? '',
      downloadSpeed: (json['download_speed'] as num?)?.toInt() ?? 0,
      progress: rawProgress <= 1 ? rawProgress * 100 : rawProgress,
      files: ((json['files'] as List<dynamic>?) ?? const <dynamic>[])
          .map(
            (dynamic item) =>
                TorBoxTorrentFile.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class AddonCatalog {
  const AddonCatalog({
    required this.type,
    required this.id,
    required this.name,
  });

  final String type;
  final String id;
  final String name;

  factory AddonCatalog.fromJson(Map<String, dynamic> json) {
    return AddonCatalog(
      type: (json['type'] as String?) ?? '',
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'id': id,
      'name': name,
    };
  }
}

class AddonResource {
  const AddonResource({
    required this.name,
    required this.types,
    required this.idPrefixes,
  });

  final String name;
  final List<String> types;
  final List<String> idPrefixes;

  factory AddonResource.fromDynamic(dynamic value) {
    if (value is String) {
      return AddonResource(name: value, types: const <String>[], idPrefixes: const <String>[]);
    }

    final Map<String, dynamic> json = value as Map<String, dynamic>;
    return AddonResource(
      name: (json['name'] as String?) ?? '',
      types: ((json['types'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      idPrefixes: ((json['idPrefixes'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'types': types,
      'idPrefixes': idPrefixes,
    };
  }
}

class AddonManifest {
  const AddonManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.url,
    required this.originalUrl,
    this.description,
    this.types = const <String>[],
    this.catalogs = const <AddonCatalog>[],
    this.resources = const <AddonResource>[],
    this.idPrefixes = const <String>[],
    this.logo,
    this.background,
    this.configurable = false,
    this.configurationRequired = false,
  });

  final String id;
  final String name;
  final String version;
  final String? description;
  final String url;
  final String originalUrl;
  final List<String> types;
  final List<AddonCatalog> catalogs;
  final List<AddonResource> resources;
  final List<String> idPrefixes;
  final String? logo;
  final String? background;
  final bool configurable;
  final bool configurationRequired;

  bool supportsContent(String mediaType, String id) {
    final bool hasStreamResource = resources.any(
      (AddonResource resource) => resource.name == 'stream',
    );
    if (!hasStreamResource) {
      return false;
    }

    if (idPrefixes.isNotEmpty &&
        !idPrefixes.any((String prefix) => id.startsWith(prefix))) {
      return false;
    }

    final Iterable<AddonResource> streamResources = resources.where(
      (AddonResource resource) => resource.name == 'stream',
    );
    for (final AddonResource resource in streamResources) {
      if (resource.types.isNotEmpty &&
          !resource.types.contains(mediaType) &&
          !(mediaType == 'series' && resource.types.contains('tv'))) {
        continue;
      }

      if (resource.idPrefixes.isNotEmpty &&
          !resource.idPrefixes.any((String prefix) => id.startsWith(prefix))) {
        continue;
      }

      return true;
    }

    return streamResources.isEmpty;
  }

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> behaviorHints =
        json['behaviorHints'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    return AddonManifest(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Unknown addon',
      version: (json['version'] as String?) ?? '0.0.0',
      description: json['description'] as String?,
      url: (json['url'] as String?) ?? '',
      originalUrl: (json['originalUrl'] as String?) ?? '',
      types: ((json['types'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      catalogs: ((json['catalogs'] as List<dynamic>?) ?? const <dynamic>[])
          .map(
            (dynamic item) =>
                AddonCatalog.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      resources: ((json['resources'] as List<dynamic>?) ?? const <dynamic>[])
          .map(AddonResource.fromDynamic)
          .toList(growable: false),
      idPrefixes: ((json['idPrefixes'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      logo: json['logo'] as String?,
      background: json['background'] as String?,
      configurable: behaviorHints['configurable'] as bool? ?? false,
      configurationRequired:
          behaviorHints['configurationRequired'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'version': version,
      'description': description,
      'url': url,
      'originalUrl': originalUrl,
      'types': types,
      'catalogs': catalogs.map((AddonCatalog item) => item.toJson()).toList(),
      'resources': resources.map((AddonResource item) => item.toJson()).toList(),
      'idPrefixes': idPrefixes,
      'logo': logo,
      'background': background,
      'behaviorHints': <String, dynamic>{
        'configurable': configurable,
        'configurationRequired': configurationRequired,
      },
    };
  }
}

class StreamSource {
  const StreamSource({
    required this.id,
    required this.provider,
    required this.sourceDisplayName,
    required this.title,
    required this.description,
    required this.quality,
    required this.sizeLabel,
    required this.isCached,
    this.infoHash,
    this.directUrl,
    this.fileIndex,
  });

  final String id;
  final String provider;
  final String sourceDisplayName;
  final String title;
  final String description;
  final String quality;
  final String sizeLabel;
  final bool isCached;
  final String? infoHash;
  final String? directUrl;
  final int? fileIndex;

  bool get isDirectUrl => directUrl != null && directUrl!.isNotEmpty;

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    return StreamSource(
      id: json['id'] as String,
      provider: json['provider'] as String,
      sourceDisplayName: json['sourceDisplayName'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      quality: json['quality'] as String? ?? 'Unknown',
      sizeLabel: json['sizeLabel'] as String? ?? '',
      isCached: json['isCached'] as bool? ?? false,
      infoHash: json['infoHash'] as String?,
      directUrl: json['directUrl'] as String?,
      fileIndex: (json['fileIndex'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'provider': provider,
      'sourceDisplayName': sourceDisplayName,
      'title': title,
      'description': description,
      'quality': quality,
      'sizeLabel': sizeLabel,
      'isCached': isCached,
      'infoHash': infoHash,
      'directUrl': directUrl,
      'fileIndex': fileIndex,
    };
  }
}

class IndexerHealth {
  const IndexerHealth({
    required this.isOnline,
    required this.responseTime,
    required this.streamCount,
    this.error,
  });

  final bool isOnline;
  final int responseTime;
  final int streamCount;
  final String? error;
}

class MagnetHistoryItem {
  const MagnetHistoryItem({
    required this.hash,
    required this.addedAt,
  });

  final String hash;
  final int addedAt;

  factory MagnetHistoryItem.fromJson(Map<String, dynamic> json) {
    return MagnetHistoryItem(
      hash: (json['hash'] as String?) ?? '',
      addedAt: (json['addedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hash': hash,
      'addedAt': addedAt,
    };
  }
}
