import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';
import 'connected_services_screen.dart';
import 'mdblist_ratings_screen.dart';
import 'tmdb_enrichment_screen.dart';

class IntegrationsScreen extends StatelessWidget {
  const IntegrationsScreen({super.key});

  void _openTmdbEnrichment(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TmdbEnrichmentScreen(),
      ),
    );
  }

  void _openMdbListRatings(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MdbListRatingsScreen(),
      ),
    );
  }

  void _openConnectedServices(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ConnectedServicesScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppSettingsRepository.settingsNotifier,
      builder: (BuildContext context, AppSettings settings, Widget? child) {
        final Color accent = LayoutOptions.accentFor(settings);
        return Scaffold(
          backgroundColor: LayoutOptions.backgroundFor(settings),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 32),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back_rounded, color: accent),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Integrations',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const _SectionLabel('INTEGRATIONS'),
                _IntegrationGroup(
                  children: <Widget>[
                    _IntegrationTile(
                      icon: Icons.movie_filter_rounded,
                      title: 'TMDB Enrichment',
                      subtitle: 'Metadata enrichment controls',
                      accent: accent,
                      onTap: () => _openTmdbEnrichment(context),
                    ),
                    _IntegrationTile(
                      icon: Icons.star_rate_rounded,
                      title: 'MDBList Ratings',
                      subtitle: 'External ratings providers',
                      accent: accent,
                      onTap: () => _openMdbListRatings(context),
                    ),
                    _IntegrationTile(
                      icon: Icons.cloud_queue_rounded,
                      title: 'Connected Services',
                      subtitle: 'Connect accounts for links and library access',
                      accent: accent,
                      onTap: () => _openConnectedServices(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}

class _IntegrationGroup extends StatelessWidget {
  const _IntegrationGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: accent),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          height: 1.35,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: accent.withOpacity(0.78),
      ),
    );
  }
}
