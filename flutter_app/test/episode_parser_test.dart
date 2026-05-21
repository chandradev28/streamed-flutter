import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/models/torbox_models.dart';
import 'package:flutter_app/src/services/episode_parser.dart';

void main() {
  test('parses common episode filename formats', () {
    expect(
      parseEpisodeInfo('Show.Name.S02E05.1080p.WEB-DL.mkv'),
      (season: 2, episode: 5),
    );
    expect(
      parseEpisodeInfo('Show Name 1x09 BluRay.mkv'),
      (season: 1, episode: 9),
    );
    expect(
      parseEpisodeInfo('Season 3 Episode 7 - Finale.mp4'),
      (season: 3, episode: 7),
    );
  });

  test('groups season pack files and extras', () {
    final List<TorBoxTorrentFile> files = <TorBoxTorrentFile>[
      const TorBoxTorrentFile(
        id: 1,
        name: 'Show.Name.S01E01.Pilot.mkv',
        size: 1000,
      ),
      const TorBoxTorrentFile(
        id: 2,
        name: 'Show.Name.S01E02.Second.Wind.mkv',
        size: 1000,
      ),
      const TorBoxTorrentFile(
        id: 3,
        name: 'Show.Name.Special.Preview.mp4',
        size: 500,
      ),
      const TorBoxTorrentFile(
        id: 4,
        name: 'Show.Name.S02E01.Return.mkv',
        size: 1000,
      ),
    ];

    final List<SeasonFileGroup> groups = parseSeasonPack(files);

    expect(groups.length, 3);
    expect(groups[0].season, 1);
    expect(groups[0].episodes.length, 2);
    expect(groups[0].episodes.first.title, 'Pilot');
    expect(groups[1].season, 2);
    expect(groups[1].episodes.single.episode, 1);
    expect(groups[2].season, -1);
    expect(groups[2].episodes.single.title, 'Show.Name.Special.Preview');
  });

  test('detects movie bundles and season pack titles', () {
    final List<TorBoxTorrentFile> movieFiles = <TorBoxTorrentFile>[
      const TorBoxTorrentFile(id: 1, name: 'Movie.Part.1.mkv', size: 1000),
      const TorBoxTorrentFile(id: 2, name: 'Movie.Part.2.mkv', size: 1000),
    ];

    expect(isMovieTorrent(movieFiles), isTrue);
    expect(isSeasonPackTitle('Show Name Season 2 Complete 1080p'), isTrue);
    expect(isSeasonPackTitle('Show Name S02E05 1080p'), isFalse);
  });
}
