import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/models/search_result.dart';
import 'package:flutter_app/src/screens/search_screen.dart';
import 'package:flutter_app/src/services/tmdb_search_service.dart';

void main() {
  testWidgets('shows idle state before searching', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SearchScreen(
            searchService: _FakeSearchService(<SearchResult>[]),
          ),
        ),
      ),
    );

    expect(find.text('Search Movies & TV Shows'), findsOneWidget);
    expect(find.text('No results found'), findsNothing);
  });

  testWidgets('searches and filters movie and tv results', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SearchScreen(
            searchService: _FakeSearchService(<SearchResult>[
              SearchResult(
                id: 1,
                mediaType: 'movie',
                posterPath: null,
                backdropPath: null,
                overview: 'A movie',
                voteAverage: 7.5,
                voteCount: 120,
                popularity: 200,
                genreIds: <int>[28],
                originalLanguage: 'en',
                adult: false,
                title: 'The Movie',
              ),
              SearchResult(
                id: 2,
                mediaType: 'tv',
                posterPath: null,
                backdropPath: null,
                overview: 'A show',
                voteAverage: 8.1,
                voteCount: 99,
                popularity: 180,
                genreIds: <int>[18],
                originalLanguage: 'en',
                adult: false,
                name: 'The Show',
              ),
            ]),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'the');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('2 results found'), findsOneWidget);
    expect(find.text('The Movie'), findsOneWidget);
    expect(find.text('The Show'), findsOneWidget);

    await tester.tap(find.text('Movies'));
    await tester.pump();

    expect(find.text('1 result found'), findsOneWidget);
    expect(find.text('The Movie'), findsOneWidget);
    expect(find.text('The Show'), findsNothing);
  });
}

class _FakeSearchService implements SearchService {
  const _FakeSearchService(this.results);

  final List<SearchResult> results;

  @override
  Future<List<SearchResult>> searchMulti(String query) async {
    return results;
  }
}
