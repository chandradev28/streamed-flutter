import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/models/tmdb_media_models.dart';
import 'package:flutter_app/src/screens/movie_detail_screen.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('movie detail opens streamed sources flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MovieDetailScreen(
          id: 7,
          mediaType: 'movie',
          mediaService: const FakeMediaService(
            detail: MediaDetail(
              id: 7,
              mediaType: 'movie',
              title: 'Movie Title',
              overview: 'A test overview.',
              posterPath: null,
              backdropPath: null,
              voteAverage: 8.4,
              voteCount: 1000,
              releaseDate: '2024-01-01',
              runtimeMinutes: 120,
              genres: <GenreItem>[GenreItem(id: 1, name: 'Sci-Fi')],
              seasons: <SeasonSummary>[],
              numberOfSeasons: 0,
              networks: <NetworkItem>[],
              imdbId: 'tt1234567',
              cast: <CastItem>[],
              similarItems: <MediaSummary>[],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Watch now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Movie Title'), findsWidgets);
  });

  testWidgets('tv detail can navigate into episodes flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MovieDetailScreen(
          id: 42,
          mediaType: 'tv',
          mediaService: const FakeMediaService(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Galaxy Squad'), findsOneWidget);
    expect(find.text('Watch now'), findsOneWidget);

    await tester.tap(find.text('Watch now'));
    await tester.pumpAndSettle();

    expect(find.text('Season 1'), findsOneWidget);
    expect(find.text('Pilot'), findsOneWidget);
  });
}
