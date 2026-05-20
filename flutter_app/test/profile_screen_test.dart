import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/models/torbox_models.dart';
import 'package:flutter_app/src/screens/profile_screen.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('saves torbox api key and shows account library', (
    WidgetTester tester,
  ) async {
    final FakeAppSettingsRepository settingsRepository =
        FakeAppSettingsRepository();
    final FakeTorBoxApiService torBoxApiService = FakeTorBoxApiService(
      settingsRepository: settingsRepository,
      user: const TorBoxUser(
        email: 'test@example.com',
        plan: 'Pro',
        createdAt: '2026-05-20T00:00:00Z',
        totalSlots: 10,
        usedSlots: 2,
        premiumExpiresAt: '2026-06-20T00:00:00Z',
      ),
      torrents: const <TorBoxTorrent>[
        TorBoxTorrent(
          id: 1,
          hash: 'abc123',
          name: 'Sample Torrent',
          size: 1073741824,
          downloadState: 'cached',
          downloadSpeed: 0,
          progress: 100,
          files: <TorBoxTorrentFile>[],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          torBoxApiService: torBoxApiService,
          settingsRepository: settingsRepository,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'tb_test_key');
    await tester.tap(find.text('Save key'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('Sample Torrent'), findsOneWidget);
    expect(find.text('TorBox library (1)'), findsOneWidget);
  });
}
