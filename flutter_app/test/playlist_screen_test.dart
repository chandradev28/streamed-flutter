import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/models/playlist_movie.dart';
import 'package:flutter_app/src/screens/playlist_screen.dart';
import 'package:flutter_app/src/services/tmdb_playlist_service.dart';

void main() {
  testWidgets('does not overflow on a small phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlaylistScreen(
            playlistService: _FakePlaylistService(
              <int, List<PlaylistMovie>>{
                8: <PlaylistMovie>[
                  PlaylistMovie(
                    id: 1,
                    title: 'Netflix Hit',
                    posterPath: null,
                    releaseDate: '2024-04-16',
                  ),
                  PlaylistMovie(
                    id: 2,
                    title: 'Another Pick',
                    posterPath: null,
                    releaseDate: '2024-05-01',
                  ),
                ],
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Playlist'), findsOneWidget);
  });

  testWidgets('loads default provider content', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlaylistScreen(
            playlistService: _FakePlaylistService(
              <int, List<PlaylistMovie>>{
                8: <PlaylistMovie>[
                  PlaylistMovie(
                    id: 1,
                    title: 'Netflix Hit',
                    posterPath: null,
                    releaseDate: '2024-04-16',
                  ),
                ],
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('NETFLIX HIT'), findsOneWidget);
    expect(find.text('APR 16'), findsOneWidget);
  });

  testWidgets('switches provider chips and reloads titles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlaylistScreen(
            playlistService: _FakePlaylistService(
              <int, List<PlaylistMovie>>{
                8: <PlaylistMovie>[
                  PlaylistMovie(
                    id: 1,
                    title: 'Netflix Hit',
                    posterPath: null,
                    releaseDate: '2024-04-16',
                  ),
                ],
                15: <PlaylistMovie>[
                  PlaylistMovie(
                    id: 2,
                    title: 'Hulu Pick',
                    posterPath: null,
                    releaseDate: '2024-06-02',
                  ),
                ],
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('NETFLIX HIT'), findsOneWidget);

    await tester.ensureVisible(find.text('Hulu'));
    await tester.tap(find.text('Hulu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('HULU PICK'), findsOneWidget);
    expect(find.text('JUN 2'), findsOneWidget);
  });

  testWidgets('keeps cached provider titles when a refresh fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaylistScreen(
            playlistService: _FlakyPlaylistService(
              <int, List<PlaylistMovie>>{
                8: <PlaylistMovie>[
                  const PlaylistMovie(
                    id: 1,
                    title: 'Netflix Hit',
                    posterPath: null,
                    releaseDate: '2024-04-16',
                  ),
                ],
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('NETFLIX HIT'), findsOneWidget);

    await tester.tap(find.text('Netflix'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('NETFLIX HIT'), findsOneWidget);
    expect(find.text('No playlist titles found'), findsNothing);
  });
}

class _FakePlaylistService implements PlaylistService {
  const _FakePlaylistService(this.responses);

  final Map<int, List<PlaylistMovie>> responses;

  @override
  Future<List<PlaylistMovie>> getMoviesByProvider(int providerId) async {
    return responses[providerId] ?? const <PlaylistMovie>[];
  }
}

class _FlakyPlaylistService implements PlaylistService {
  _FlakyPlaylistService(this.responses);

  final Map<int, List<PlaylistMovie>> responses;
  final Map<int, int> _calls = <int, int>{};

  @override
  Future<List<PlaylistMovie>> getMoviesByProvider(int providerId) async {
    final int callCount = (_calls[providerId] ?? 0) + 1;
    _calls[providerId] = callCount;
    if (callCount > 1) {
      throw Exception('network blink');
    }

    return responses[providerId] ?? const <PlaylistMovie>[];
  }
}
