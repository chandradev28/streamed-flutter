import 'package:flutter/material.dart';

import '../services/app_settings_repository.dart';
import '../services/real_debrid_api_service.dart';
import '../services/torbox_api_service.dart';
import '../theme/app_colors.dart';
import 'addons_screen.dart';
import 'integrations_screen.dart';
import 'layout_screen.dart';
import 'torboxers_screen.dart';

class ProfileScreen extends StatefulWidget {
  ProfileScreen({
    super.key,
    TorBoxApiService? torBoxApiService,
    RealDebridApiService? realDebridApiService,
    AppSettingsRepository? settingsRepository,
  })  : torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        realDebridApiService = realDebridApiService ?? RealDebridApiService(),
        settingsRepository = settingsRepository ?? AppSettingsRepository();

  final TorBoxApiService torBoxApiService;
  final RealDebridApiService realDebridApiService;
  final AppSettingsRepository settingsRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddons() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AddonsScreen(),
      ),
    );
  }

  void _openIntegrations() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const IntegrationsScreen(),
      ),
    );
  }

  void _openLayout() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => LayoutScreen(),
      ),
    );
  }

  void _openTorboxers() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TorboxersScreen(),
      ),
    );
  }

  bool _matchesSettingsSearch(String value) {
    final String query = _searchController.text.trim().toLowerCase();
    return query.isEmpty || value.toLowerCase().contains(query);
  }

  void _showPlaceholder(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title is not wired yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showAccount = _matchesSettingsSearch(
      'account profile trakt sync switch',
    );
    final bool showGeneral = _matchesSettingsSearch(
      'general layout content discovery addons downloads playback integrations notifications torboxers',
    );
    final bool showAbout = _matchesSettingsSearch(
      'about supporters contributors licenses attribution',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 140),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Settings',
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
            const SizedBox(height: 22),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Search settings...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.cardBackground,
                hintStyle: const TextStyle(color: AppColors.textSubtle),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (showAccount) ...<Widget>[
              const _SettingsSectionLabel('ACCOUNT'),
              _SettingsGroupCard(
                children: <Widget>[
                  _SettingsActionTile(
                    icon: Icons.groups_rounded,
                    title: 'Switch Profile',
                    subtitle: 'Change to a different profile.',
                    onTap: () => _showPlaceholder('Switch Profile'),
                  ),
                  _SettingsActionTile(
                    icon: Icons.account_circle_rounded,
                    title: 'Account',
                    subtitle: 'Account and sync status',
                    onTap: () => _showPlaceholder('Account'),
                  ),
                  _SettingsActionTile(
                    icon: Icons.checklist_rtl_rounded,
                    title: 'Trakt',
                    subtitle: 'Open Trakt connection screen',
                    accent: const Color(0xFFCE3CCB),
                    onTap: () => _showPlaceholder('Trakt'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
            ],
            if (showGeneral) ...<Widget>[
              const _SettingsSectionLabel('GENERAL'),
              _SettingsGroupCard(
                children: <Widget>[
                  _SettingsActionTile(
                    icon: Icons.palette_rounded,
                    title: 'Layout',
                    subtitle: 'Home structure and poster styles',
                    onTap: _openLayout,
                  ),
                  _SettingsActionTile(
                    icon: Icons.extension_rounded,
                    title: 'Content & Discovery',
                    subtitle: 'Manage addons and discovery sources.',
                    onTap: _openAddons,
                  ),
                  _SettingsActionTile(
                    icon: Icons.cloud_download_rounded,
                    title: 'Downloads',
                    subtitle: 'Manage your downloaded movies and episodes.',
                    onTap: () => _showPlaceholder('Downloads'),
                  ),
                  _SettingsActionTile(
                    icon: Icons.play_arrow_rounded,
                    title: 'Playback',
                    subtitle: 'Player, subtitles, and auto-play',
                    onTap: () => _showPlaceholder('Playback'),
                  ),
                  _SettingsActionTile(
                    icon: Icons.link_rounded,
                    title: 'Integrations',
                    subtitle: 'Manage available integrations',
                    onTap: _openIntegrations,
                  ),
                  _SettingsActionTile(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    subtitle:
                        'Manage episode release alerts and test notifications.',
                    onTap: () => _showPlaceholder('Notifications'),
                  ),
                  _SettingsActionTile(
                    icon: Icons.rocket_launch_rounded,
                    title: 'Torboxers',
                    subtitle: 'Search streams and imported engines',
                    onTap: _openTorboxers,
                  ),
                ],
              ),
              const SizedBox(height: 22),
            ],
            if (showAbout) ...<Widget>[
              const _SettingsSectionLabel('ABOUT'),
              _SettingsGroupCard(
                children: <Widget>[
                  _SettingsActionTile(
                    icon: Icons.favorite_rounded,
                    title: 'Supporters & Contributors',
                    subtitle: 'Open recognition and project credits',
                    onTap: () => _showPlaceholder('Supporters & Contributors'),
                  ),
                  _SettingsActionTile(
                    icon: Icons.article_rounded,
                    title: 'Licenses & Attribution',
                    subtitle: 'Open package licenses and notices',
                    onTap: () => _showPlaceholder('Licenses & Attribution'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.children});

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

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: (accent ?? Colors.white)
              .withOpacity(accent == null ? 0.08 : 0.22),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.text, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          height: 1.25,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
    );
  }
}
