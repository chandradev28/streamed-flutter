import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/models/torbox_models.dart';
import 'package:flutter_app/src/services/stream_badge_service.dart';

void main() {
  test('parses Badger export filters and matches stream text', () {
    const StreamBadgeService service = StreamBadgeService();

    final List<StreamBadge> badges = service.parseBadges('''
{
  "filters": [
    {
      "name": "4K",
      "isEnabled": true,
      "pattern": "2160p|4K",
      "imageURL": "https://example.test/4k.png"
    },
    {
      "name": "Disabled",
      "isEnabled": false,
      "pattern": "WEB"
    },
    {
      "name": "HDR10",
      "pattern": "HDR10"
    }
  ]
}
''');

    expect(badges.map((StreamBadge badge) => badge.name), <String>[
      '4K',
      'HDR10',
    ]);

    final List<StreamBadge> matches = service.matchesForSource(
      badges: badges,
      source: const StreamSource(
        id: '1',
        provider: 'addon',
        sourceDisplayName: 'AIOStreams',
        title: 'Movie.2026.2160p.WEB-DL.HDR10.mkv',
        description: 'HEVC DV HDR',
        quality: '4K',
        sizeLabel: '17.6 GB',
        isCached: true,
      ),
    );

    expect(matches.map((StreamBadge badge) => badge.name), <String>[
      '4K',
      'HDR10',
    ]);
  });

  test('parses nested Badger groups and quality aliases', () {
    const StreamBadgeService service = StreamBadgeService();

    final List<StreamBadge> badges = service.parseBadges('''
{
  "groups": [
    {
      "name": "Quality",
      "badges": [
        {
          "name": "UHD 4K",
          "enabled": "true",
          "pattern": "\\\\b2160p\\\\b",
          "image": "https://example.test/uhd.png"
        },
        {
          "name": "Hidden",
          "disabled": true,
          "pattern": "Supergirl"
        }
      ]
    }
  ]
}
''');

    expect(badges.map((StreamBadge badge) => badge.name), <String>[
      'UHD 4K',
    ]);
    expect(badges.single.imageUrl, 'https://example.test/uhd.png');

    final List<StreamBadge> matches = service.matchesForSource(
      badges: badges,
      source: const StreamSource(
        id: '2',
        provider: 'addon',
        sourceDisplayName: 'StremThru Torz',
        title: 'Torz',
        description: '4k',
        quality: '4K',
        sizeLabel: '544 MB',
        isCached: false,
      ),
    );

    expect(matches.map((StreamBadge badge) => badge.name), <String>[
      'UHD 4K',
    ]);
  });
}
