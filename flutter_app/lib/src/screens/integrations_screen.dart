import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
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
                  badgeColor: const Color(0xFF223936),
                  onTap: () => _openTmdbEnrichment(context),
                ),
                _IntegrationTile(
                  icon: Icons.star_rate_rounded,
                  title: 'MDBList Ratings',
                  subtitle: 'External ratings providers',
                  badgeColor: const Color(0xFF1D3E6E),
                  onTap: () => _openMdbListRatings(context),
                ),
                _IntegrationTile(
                  icon: Icons.cloud_queue_rounded,
                  title: 'Connected Services',
                  subtitle: 'Connect accounts for links and library access',
                  onTap: () => _openConnectedServices(context),
                ),
              ],
            ),
          ],
        ),
      ),
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
    this.badgeColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: badgeColor ?? Colors.white.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.text),
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
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
    );
  }
}
