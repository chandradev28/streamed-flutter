import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/stream_catalog_service.dart';
import '../theme/app_colors.dart';

class IndexerStatusScreen extends StatefulWidget {
  const IndexerStatusScreen({
    super.key,
    StreamCatalogService? streamCatalogService,
  }) : streamCatalogService =
            streamCatalogService ?? const StreamCatalogService();

  final StreamCatalogService streamCatalogService;

  @override
  State<IndexerStatusScreen> createState() => _IndexerStatusScreenState();
}

class _IndexerStatusScreenState extends State<IndexerStatusScreen> {
  IndexerHealth? _torrentio;
  bool _loading = true;
  DateTime? _lastCheckedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final IndexerHealth torrentio =
        await widget.streamCatalogService.checkTorrentioHealth();

    if (!mounted) {
      return;
    }

    setState(() {
      _torrentio = torrentio;
      _lastCheckedAt = DateTime.now();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Source Status'),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const Text(
              'Built-in source',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This checks the same Torrentio Stremio addon from torrentio.strem.fun/configure that Streamed uses for built-in sources.',
              style: TextStyle(color: AppColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 18),
            _IndexerCard(
              title: 'Torrentio',
              subtitle: 'torrentio.strem.fun/configure',
              health: _torrentio,
              loading: _loading,
            ),
            const SizedBox(height: 18),
            if (_lastCheckedAt != null)
              Text(
                'Last checked at ${TimeOfDay.fromDateTime(_lastCheckedAt!).format(context)}',
                style: const TextStyle(color: AppColors.textSubtle),
              ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Provider-level checks are intentionally hidden here because Torrentio is one configurable addon. If this card is online, Streamed can reach the built-in source.',
                style: TextStyle(color: AppColors.textMuted, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndexerCard extends StatelessWidget {
  const _IndexerCard({
    required this.title,
    required this.subtitle,
    required this.health,
    required this.loading,
  });

  final String title;
  final String subtitle;
  final IndexerHealth? health;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    if (health == null) {
      statusColor = AppColors.textSubtle;
    } else if (!health!.isOnline) {
      statusColor = const Color(0xFFEF4444);
    } else if (health!.responseTime > 2000) {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.check_circle,
                color: AppColors.text,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const LinearProgressIndicator(
              minHeight: 4,
              color: AppColors.text,
              backgroundColor: Color(0x22FFFFFF),
            )
          else if (health != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _HealthChip(label: '${health!.responseTime} ms'),
                _HealthChip(label: '${health!.streamCount} streams'),
                _HealthChip(label: health!.isOnline ? 'Online' : 'Offline'),
              ],
            ),
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
