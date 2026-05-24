import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/models/tmdb_media_models.dart';
import 'package:flutter_app/src/models/watch_history_item.dart';
import 'package:flutter_app/src/screens/home_screen.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('renders home sections and continue watching cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          mediaService: const FakeMediaService(),
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
      find.text('Top 10 Movies This Week'),
      160,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Top 10 Movies This Week'), findsOneWidget);
    expect(find.text('Top 10 Series This Week'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('New Releases'),
      160,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('New Releases'), findsOneWidget);
    expect(find.text('Trending One'), findsWidgets);
  });

  testWidgets('keeps rendering available home rows when one fetch fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          mediaService: const _NowPlayingFailureMediaService(),
          watchHistoryRepository: const FakeWatchHistoryRepository(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Trending One'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Top 10 Movies This Week'),
      160,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Top 10 Movies This Week'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('New Releases'),
      160,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('New Releases'), findsOneWidget);
  });
}

class _NowPlayingFailureMediaService extends FakeMediaService {
  const _NowPlayingFailureMediaService();

  @override
  Future<List<MediaSummary>> getNowPlayingMovies() async {
    throw Exception('network blink');
  }
}
