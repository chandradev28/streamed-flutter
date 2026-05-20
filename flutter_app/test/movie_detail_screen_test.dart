import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/screens/movie_detail_screen.dart';

import 'test_fakes.dart';

void main() {
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
