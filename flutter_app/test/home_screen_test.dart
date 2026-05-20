import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    expect(find.text('Streamed'), findsOneWidget);
    expect(find.text('Open Torboxers'), findsOneWidget);
    expect(find.text('Top trending movies'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(find.text('Continue Watching'), findsOneWidget);
    expect(find.text('New Releases'), findsOneWidget);
    expect(find.text('Trending One'), findsOneWidget);
    expect(find.text('Space Show'), findsOneWidget);
  });
}
