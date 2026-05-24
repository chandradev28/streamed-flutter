import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/app.dart';
import 'package:flutter_app/src/screens/home_screen.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('shows migrated home shell by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      StreamedApp(
        home: HomeScreen(
          mediaService: const FakeMediaService(),
          watchHistoryRepository: const FakeWatchHistoryRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
        find.byKey(const ValueKey<String>('home-menu-button')), findsOneWidget);
    expect(find.text('Streamed'), findsOneWidget);
    expect(find.text('Top trending movies'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(find.text('New Releases'), findsOneWidget);
  });
}
