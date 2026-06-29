import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/models/torbox_models.dart';
import 'package:flutter_app/src/models/watch_history_item.dart';
import 'package:flutter_app/src/screens/home_screen.dart';
import 'package:flutter_app/src/services/stremio_addons_service.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('renders addon catalog shelves and continue watching cards', (
    WidgetTester tester,
  ) async {
    final _FakeAddonsService addonsService = _FakeAddonsService.withCatalogs();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          mediaService: const FakeMediaService(),
          settingsRepository: FakeAppSettingsRepository(),
          addonsService: addonsService,
          watchHistoryRepository: const FakeWatchHistoryRepository(
            items: <WatchHistoryItem>[
              WatchHistoryItem(
                id: 'tv-1',
                tmdbId: 101,
                mediaType: 'tv',
                title: 'Space Show',
                posterPath: null,
                progress: 42,
                currentTime: 1200,
                duration: 2400,
                lastWatched: 1,
                addedAt: 1,
                seasonNumber: 2,
                episodeNumber: 4,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('home-menu-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('home-profile-button')),
      findsOneWidget,
    );
    expect(find.text('Streamed'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Continue Watching'),
      160,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Continue Watching'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Space Show'),
      80,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Space Show'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Featured Movies'),
      160,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Featured Movies'), findsOneWidget);
    expect(find.text('AIOStreams'), findsWidgets);
    expect(find.text('Addon Poster One'), findsWidgets);
  });

  testWidgets('shows addon setup state when no catalog rows exist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          mediaService: const FakeMediaService(),
          settingsRepository: FakeAppSettingsRepository(),
          addonsService: _FakeAddonsService.empty(),
          watchHistoryRepository: const FakeWatchHistoryRepository(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Add your first catalog addon'), findsOneWidget);
    expect(find.text('Manage addons'), findsOneWidget);
    expect(find.text('Top 10 Movies This Week'), findsNothing);
    expect(find.text('New Releases'), findsNothing);
  });
}

class _FakeAddonsService extends StremioAddonsService {
  _FakeAddonsService({
    required this.addons,
    required this.rows,
  });

  factory _FakeAddonsService.empty() {
    return _FakeAddonsService(
      addons: const <AddonManifest>[],
      rows: const <AddonCatalogRow>[],
    );
  }

  factory _FakeAddonsService.withCatalogs() {
    const AddonManifest addon = AddonManifest(
      id: 'aiostreams',
      name: 'AIOStreams',
      version: '1.0.0',
      url: 'https://example.test/addon',
      originalUrl: 'https://example.test/addon/manifest.json',
      types: <String>['movie', 'series'],
      resources: <AddonResource>[
        AddonResource(
          name: 'catalog',
          types: <String>['movie'],
          idPrefixes: <String>[],
        ),
      ],
      catalogs: <AddonCatalog>[
        AddonCatalog(
          type: 'movie',
          id: 'featured',
          name: 'Featured Movies',
        ),
      ],
    );

    const AddonCatalog catalog = AddonCatalog(
      type: 'movie',
      id: 'featured',
      name: 'Featured Movies',
    );

    return _FakeAddonsService(
      addons: const <AddonManifest>[addon],
      rows: const <AddonCatalogRow>[
        AddonCatalogRow(
          addonName: 'AIOStreams',
          catalogName: 'Featured Movies',
          catalog: catalog,
          addon: addon,
          items: <AddonCatalogItem>[
            AddonCatalogItem(
              id: 'tt0000001',
              type: 'movie',
              name: 'Addon Poster One',
              poster: '/poster-one.jpg',
              background: '/backdrop-one.jpg',
              releaseInfo: '2026',
            ),
          ],
        ),
      ],
    );
  }

  final List<AddonManifest> addons;
  final List<AddonCatalogRow> rows;

  @override
  Future<List<AddonManifest>> getInstalledAddons() async {
    return addons;
  }

  @override
  Future<List<AddonCatalogRow>> fetchAllCatalogRows() async {
    return rows;
  }

  @override
  String resolveAddonUrl(AddonManifest addon, String? raw) {
    if (raw == null || raw.isEmpty) {
      return '';
    }
    return raw.startsWith('http') ? raw : '${addon.url}$raw';
  }
}
