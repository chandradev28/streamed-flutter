import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/magnet_history_repository.dart';
import '../services/torbox_api_service.dart';
import '../theme/app_colors.dart';
import 'video_player_screen.dart';

class MagnetScreen extends StatefulWidget {
  MagnetScreen({
    super.key,
    TorBoxApiService? torBoxApiService,
    MagnetHistoryRepository? historyRepository,
  })  : torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        historyRepository = historyRepository ?? MagnetHistoryRepository();

  final TorBoxApiService torBoxApiService;
  final MagnetHistoryRepository historyRepository;

  @override
  State<MagnetScreen> createState() => _MagnetScreenState();
}

class _MagnetScreenState extends State<MagnetScreen> {
  final TextEditingController _controller = TextEditingController();
  List<TorBoxTorrent> _torrents = const <TorBoxTorrent>[];
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final Set<String> hashes = await widget.historyRepository.getHashes();
    final List<TorBoxTorrent> allTorrents =
        await widget.torBoxApiService.getUserTorrents();
    final List<TorBoxTorrent> torrents = allTorrents
        .where((TorBoxTorrent torrent) =>
            hashes.contains(torrent.hash.toLowerCase()))
        .toList(growable: false);

    torrents.sort(
        (TorBoxTorrent a, TorBoxTorrent b) => b.progress.compareTo(a.progress));

    if (!mounted) {
      return;
    }

    setState(() {
      _torrents = torrents;
      _loading = false;
    });
  }

  Future<void> _addMagnets() async {
    final List<String> inputs = _controller.text
        .split(RegExp(r'[\r\n]+'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    if (inputs.isEmpty) {
      return;
    }

    setState(() {
      _adding = true;
    });

    final List<String> addedHashes = <String>[];
    int successCount = 0;
    for (final String input in inputs) {
      final TorBoxTorrent? torrent =
          await widget.torBoxApiService.addTorrent(input);
      if (torrent != null) {
        successCount += 1;
        addedHashes.add(torrent.hash);
      }
    }

    await widget.historyRepository.addHashes(addedHashes);
    _controller.clear();
    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _adding = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          successCount == 0
              ? 'No torrents were added.'
              : 'Added $successCount torrent${successCount == 1 ? '' : 's'} to TorBox.',
        ),
      ),
    );
  }

  Future<void> _removeFromHistory(TorBoxTorrent torrent) async {
    await widget.historyRepository.removeHash(torrent.hash);
    await _load();
  }

  Future<void> _deleteTorrent(TorBoxTorrent torrent) async {
    await widget.torBoxApiService.deleteTorrent(torrent.id);
    await widget.historyRepository.removeHash(torrent.hash);
    await _load();
  }

  void _openPlayer(TorBoxTorrent torrent) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => VideoPlayerScreen(
          title: torrent.name,
          torrentId: torrent.id,
          torrentHash: torrent.hash,
          initialFiles: torrent.files,
          provider: 'torbox',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Magnet'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Add magnet links',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Paste one magnet or info hash per line. Torrent file upload is still pending in the Flutter port.',
                      style:
                          TextStyle(color: AppColors.textMuted, height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      minLines: 4,
                      maxLines: 7,
                      style: const TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: 'magnet:?xt=urn:btih:...\nABCDEF123456...',
                        hintStyle: const TextStyle(color: AppColors.textSubtle),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _adding ? null : _addMagnets,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.text,
                        foregroundColor: AppColors.background,
                      ),
                      child: Text(_adding ? 'Adding...' : 'Add magnet(s)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.text),
                  ),
                )
              else if (_torrents.isEmpty)
                const _EmptyMagnetState()
              else ...<Widget>[
                Text(
                  'My torrents (${_torrents.length})',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ..._torrents.map(
                  (TorBoxTorrent torrent) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TorrentCard(
                      torrent: torrent,
                      onOpen: () => _openPlayer(torrent),
                      onRemove: () => _removeFromHistory(torrent),
                      onDelete: () => _deleteTorrent(torrent),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TorrentCard extends StatelessWidget {
  const _TorrentCard({
    required this.torrent,
    required this.onOpen,
    required this.onRemove,
    required this.onDelete,
  });

  final TorBoxTorrent torrent;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isReady = torrent.progress >= 100;
    final Color statusColor = isReady
        ? const Color(0xFF10B981)
        : torrent.downloadSpeed > 0
            ? const Color(0xFFF59E0B)
            : const Color(0xFF6366F1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  torrent.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppColors.textSubtle),
              ),
              IconButton(
                onPressed: onDelete,
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFFCA5A5)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _TorrentChip(label: _formatBytes(torrent.size)),
              _TorrentChip(label: '${torrent.progress.round()}%'),
              _TorrentChip(
                label: isReady
                    ? 'Cached'
                    : (torrent.downloadState.isEmpty
                        ? 'Queued'
                        : torrent.downloadState),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: (torrent.progress / 100).clamp(0, 1),
              color: statusColor,
              backgroundColor: Colors.white.withOpacity(0.08),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.08),
              foregroundColor: AppColors.text,
            ),
            child: Text(isReady ? 'Open player tools' : 'Open torrent files'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    const List<String> sizes = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int index = 0;
    while (value >= 1024 && index < sizes.length - 1) {
      value /= 1024;
      index += 1;
    }

    return '${value.toStringAsFixed(value >= 10 || index == 0 ? 0 : 1)} ${sizes[index]}';
  }
}

class _TorrentChip extends StatelessWidget {
  const _TorrentChip({
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyMagnetState extends StatelessWidget {
  const _EmptyMagnetState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: <Widget>[
          Icon(Icons.link_outlined, color: AppColors.textMuted, size: 36),
          SizedBox(height: 12),
          Text(
            'No magnet history yet.',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Torrents you add here stay pinned in this screen so you can revisit their caching progress quickly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
