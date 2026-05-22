import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/models/torbox_models.dart';
import 'package:flutter_app/src/services/torbox_api_service.dart';

void main() {
  test('normalizes copied torbox api keys', () {
    expect(
      TorBoxApiService.normalizeApiKey('  Bearer "79-09ea-4dc5" \n'),
      '79-09ea-4dc5',
    );
    expect(
      TorBoxApiService.normalizeApiKey('Token `abc 123`'),
      'abc123',
    );
  });

  test('parses torbox user data defensively', () {
    final TorBoxUser user = TorBoxUser.fromJson(
      const <String, dynamic>{
        'email': 'test@example.com',
        'plan': '4',
        'additional_concurrent_slots': '2',
        'total_slots': '12',
        'used_slots': '3',
        'premium_expires_at': 1810000000,
      },
    );

    expect(user.email, 'test@example.com');
    expect(user.plan, '4');
    expect(user.totalSlots, 12);
    expect(user.usedSlots, 3);
    expect(user.premiumExpiresAt, '1810000000');
  });
}
