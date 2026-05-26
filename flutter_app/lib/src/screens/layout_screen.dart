import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';

class LayoutScreen extends StatefulWidget {
  LayoutScreen({
    super.key,
    AppSettingsRepository? settingsRepository,
  }) : settingsRepository = settingsRepository ?? AppSettingsRepository();

  final AppSettingsRepository settingsRepository;

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen> {
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  Color get _accent => LayoutOptions.accentFor(_settings);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _save(AppSettings settings) async {
    setState(() {
      _settings = settings;
    });
    await widget.settingsRepository.saveSettings(settings);
  }

  Future<void> _openContinueWatching() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ContinueWatchingLayoutScreen(
          settingsRepository: widget.settingsRepository,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openPosterStyle() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PosterCardStyleScreen(
          settingsRepository: widget.settingsRepository,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LayoutOptions.backgroundFor(_settings),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _accent))
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 130),
                children: <Widget>[
                  const _LayoutTitle(title: 'Layout'),
                  const SizedBox(height: 26),
                  const _SectionLabel('THEME'),
                  _ThemeGrid(
                    settings: _settings,
                    onSelected: (String id) =>
                        _save(_settings.copyWith(layoutTheme: id)),
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('DISPLAY'),
                  _SettingsCard(
                    children: <Widget>[
                      _ToggleRow(
                        title: 'AMOLED Black',
                        subtitle:
                            'Use pure black backgrounds for OLED screens.',
                        value: _settings.amoledBlackEnabled,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(amoledBlackEnabled: value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('HOME'),
                  _SettingsCard(
                    children: <Widget>[
                      _NavigationRow(
                        icon: Icons.style_rounded,
                        title: 'Continue Watching',
                        subtitle: 'Settings for the Continue Watching section.',
                        accent: _accent,
                        onTap: _openContinueWatching,
                      ),
                      _NavigationRow(
                        icon: Icons.tune_rounded,
                        title: 'Poster Card Style',
                        subtitle: 'Tune card width and corner radius.',
                        accent: _accent,
                        onTap: _openPosterStyle,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class ContinueWatchingLayoutScreen extends StatefulWidget {
  ContinueWatchingLayoutScreen({
    super.key,
    AppSettingsRepository? settingsRepository,
  }) : settingsRepository = settingsRepository ?? AppSettingsRepository();

  final AppSettingsRepository settingsRepository;

  @override
  State<ContinueWatchingLayoutScreen> createState() =>
      _ContinueWatchingLayoutScreenState();
}

class _ContinueWatchingLayoutScreenState
    extends State<ContinueWatchingLayoutScreen> {
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  Color get _accent => LayoutOptions.accentFor(_settings);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _save(AppSettings settings) async {
    setState(() {
      _settings = settings;
    });
    await widget.settingsRepository.saveSettings(settings);
  }

  void _showSortOrderSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _SortOrderSheet(
          selected: _settings.continueWatchingSortOrder,
          accent: _accent,
          onSelected: (String value) {
            Navigator.of(context).pop();
            _save(_settings.copyWith(continueWatchingSortOrder: value));
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LayoutOptions.backgroundFor(_settings),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _accent))
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 22, 14, 88),
                children: <Widget>[
                  const _LayoutTitle(title: 'Continue\nWatching'),
                  const SizedBox(height: 14),
                  const _SectionLabel('VISIBILITY'),
                  _ContinueSettingsCard(
                    children: <Widget>[
                      _CompactToggleRow(
                        title: 'Show Continue Watching',
                        subtitle:
                            'Display the Continue Watching shelf on the Home screen.',
                        value: _settings.continueWatchingEnabled,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(continueWatchingEnabled: value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _SectionLabel('POSTER CARD STYLE'),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ContinueStyleCard(
                          title: 'Wide',
                          subtitle: 'Info-dense horizontal card',
                          icon: Icons.view_agenda_rounded,
                          selected: _settings.continueWatchingStyle == 'wide',
                          accent: _accent,
                          onTap: () => _save(
                            _settings.copyWith(continueWatchingStyle: 'wide'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ContinueStyleCard(
                          title: 'Poster',
                          subtitle: 'Artwork-first poster card',
                          icon: Icons.movie_filter_rounded,
                          selected: _settings.continueWatchingStyle == 'poster',
                          accent: _accent,
                          onTap: () => _save(
                            _settings.copyWith(continueWatchingStyle: 'poster'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _SectionLabel('UP NEXT BEHAVIOR'),
                  _ContinueSettingsCard(
                    children: <Widget>[
                      _CompactToggleRow(
                        title: 'Prefer Episode Thumbnails',
                        subtitle:
                            'Prefer episode thumbnails in Continue Watching when available.',
                        value: _settings.continueWatchingPreferEpisodeThumbs,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            continueWatchingPreferEpisodeThumbs: value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CompactToggleRow(
                        title: 'Up Next From Furthest Episode',
                        subtitle:
                            'Show next episode based on the furthest watched episode.',
                        value: _settings.continueWatchingFurthestEpisode,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            continueWatchingFurthestEpisode: value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CompactToggleRow(
                        title: 'Show Unaired Next Up Episodes',
                        subtitle: 'Include upcoming episodes before they air.',
                        value: _settings.continueWatchingShowUnaired,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            continueWatchingShowUnaired: value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CompactToggleRow(
                        title: 'Blur Unwatched in Continue Watching',
                        subtitle:
                            'Blur next episode thumbnails to avoid spoilers.',
                        value: _settings.continueWatchingBlurUnwatched,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            continueWatchingBlurUnwatched: value,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _SectionLabel('ON LAUNCH'),
                  _ContinueSettingsCard(
                    children: <Widget>[
                      _CompactToggleRow(
                        title: 'Resume prompt on launch',
                        subtitle:
                            'Show a popup to continue where you left off when opening the app.',
                        value: _settings.continueWatchingResumePrompt,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            continueWatchingResumePrompt: value,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _SectionLabel('SORT ORDER'),
                  _CompactNavigationTile(
                    title: 'Sort Order',
                    subtitle: _sortOrderLabel(
                      _settings.continueWatchingSortOrder,
                    ),
                    onTap: _showSortOrderSheet,
                  ),
                ],
              ),
      ),
    );
  }
}

class PosterCardStyleScreen extends StatefulWidget {
  PosterCardStyleScreen({
    super.key,
    AppSettingsRepository? settingsRepository,
  }) : settingsRepository = settingsRepository ?? AppSettingsRepository();

  final AppSettingsRepository settingsRepository;

  @override
  State<PosterCardStyleScreen> createState() => _PosterCardStyleScreenState();
}

class _PosterCardStyleScreenState extends State<PosterCardStyleScreen> {
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  Color get _accent => LayoutOptions.accentFor(_settings);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _save(AppSettings settings) async {
    setState(() {
      _settings = settings;
    });
    await widget.settingsRepository.saveSettings(settings);
  }

  Future<void> _reset() {
    return _save(
      _settings.copyWith(
        posterWidthPreset: 'balanced',
        posterRadiusPreset: 'rounded',
        posterLandscapeEnabled: false,
        posterHideLabels: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = LayoutOptions.posterWidth(_settings);
    final double radius = LayoutOptions.posterRadius(_settings);
    final double height =
        _settings.posterLandscapeEnabled ? width * 0.62 : width * 1.5;

    return Scaffold(
      backgroundColor: LayoutOptions.backgroundFor(_settings),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _accent))
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 110),
                children: <Widget>[
                  const _LayoutTitle(title: 'Poster Card\nStyle'),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const Expanded(
                        child: _SectionLabel(
                          'POSTER CARD STYLE',
                          bottomPadding: 0,
                        ),
                      ),
                      _SoftActionButton(
                        label: 'Reset to Default',
                        accent: _accent,
                        onTap: _reset,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    borderRadius: 8,
                    children: <Widget>[
                      const Text(
                        'Tune card width and corner radius.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14.5,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Live Preview',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: width,
                            height: height,
                            decoration: BoxDecoration(
                              color: Color.alphaBlend(
                                _accent.withOpacity(0.10),
                                AppColors.cardBackground,
                              ),
                              borderRadius: BorderRadius.circular(radius),
                              border: Border.all(
                                color: _accent.withOpacity(0.40),
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                height: 5,
                                width: width * 0.42,
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _PreviewMetrics(
                                values: <String, String>{
                                  'Width': '${width.round()}dp',
                                  'Corner radius': '${radius.round()}dp',
                                  'Height': '${height.round()}dp',
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Divider(color: Colors.white.withOpacity(0.08)),
                      const SizedBox(height: 18),
                      Text(
                        'Width (${LayoutOptions.posterWidthLabel(_settings.posterWidthPreset)})',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ChoiceWrap(
                        values: const <String>[
                          'compact',
                          'dense',
                          'standard',
                          'balanced',
                          'comfort',
                          'large',
                        ],
                        selected: _settings.posterWidthPreset,
                        labelFor: LayoutOptions.posterWidthLabel,
                        accent: _accent,
                        onSelected: (String value) => _save(
                          _settings.copyWith(posterWidthPreset: value),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Corner Radius (${LayoutOptions.posterRadiusLabel(_settings.posterRadiusPreset)})',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ChoiceWrap(
                        values: const <String>[
                          'sharp',
                          'subtle',
                          'classic',
                          'rounded',
                          'pill',
                        ],
                        selected: _settings.posterRadiusPreset,
                        labelFor: LayoutOptions.posterRadiusLabel,
                        accent: _accent,
                        onSelected: (String value) => _save(
                          _settings.copyWith(posterRadiusPreset: value),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _PosterToggleRow(
                        title: 'Landscape Posters',
                        value: _settings.posterLandscapeEnabled,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(posterLandscapeEnabled: value),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _PosterToggleRow(
                        title: 'Hide labels',
                        value: _settings.posterHideLabels,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(posterHideLabels: value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({
    required this.settings,
    required this.onSelected,
  });

  final AppSettings settings;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double spacing = 12;
            final double tileWidth = (constraints.maxWidth - (spacing * 2)) / 3;
            return Wrap(
              spacing: spacing,
              runSpacing: 16,
              children: LayoutOptions.themes.map((LayoutThemeOption option) {
                final bool selected = option.id == settings.layoutTheme;
                return GestureDetector(
                  onTap: () => onSelected(option.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: tileWidth,
                    height: 122,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? AppColors.text : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: option.color,
                          ),
                          child: selected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: option.id == 'white'
                                      ? AppColors.background
                                      : AppColors.text,
                                  size: 28,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 42,
                          height: 3,
                          decoration: BoxDecoration(
                            color: option.color,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _LayoutTitle extends StatelessWidget {
  const _LayoutTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 38,
              height: 0.98,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SoftActionButton extends StatelessWidget {
  const _SoftActionButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(
    this.label, {
    this.bottomPadding = 10,
  });

  final String label;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 2, bottom: bottomPadding),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 16),
    this.borderRadius = 22,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ContinueSettingsCard extends StatelessWidget {
  const _ContinueSettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _CompactToggleRow extends StatelessWidget {
  const _CompactToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12.5,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.8,
                    height: 1.18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Transform.scale(
          scale: 0.76,
          child: Switch(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _CompactNavigationTile extends StatelessWidget {
  const _CompactNavigationTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12.5,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.8,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.accent,
    this.icon,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 0,
      leading: icon == null
          ? null
          : Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          height: 1.2,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: accent.withOpacity(0.82),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.value,
    required this.accent,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.22,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Transform.scale(
              scale: 0.92,
              child: Switch(
                value: value,
                activeColor: accent,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterToggleRow extends StatelessWidget {
  const _PosterToggleRow({
    required this.title,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Transform.scale(
          scale: 0.88,
          child: Switch(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ContinueStyleCard extends StatelessWidget {
  const _ContinueStyleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 184,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.text : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Align(
              alignment: Alignment.topRight,
              child: Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.text : AppColors.textMuted,
                size: 17,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 94),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Icon(icon, color: AppColors.textMuted, size: 34),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                height: 1.12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.accent,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final String Function(String value) labelFor;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values.map((String value) {
        final bool isSelected = value == selected;
        return _ChoicePill(
          label: labelFor(value),
          selected: isSelected,
          accent: accent,
          onTap: () => onSelected(value),
        );
      }).toList(growable: false),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? accent.withOpacity(0.26) : Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: const BoxConstraints(minWidth: 78),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? accent.withOpacity(0.65) : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (selected) ...<Widget>[
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.text,
                  size: 15,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.text : AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewMetrics extends StatelessWidget {
  const _PreviewMetrics({
    required this.values,
  });

  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: values.entries.map((MapEntry<String, String> entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            '${entry.key}: ${entry.value}',
            style: TextStyle(
              color:
                  entry.key == 'Height' ? AppColors.textMuted : AppColors.text,
              fontSize: 16,
              height: 1.18,
              fontWeight:
                  entry.key == 'Height' ? FontWeight.w600 : FontWeight.w800,
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _SortOrderSheet extends StatelessWidget {
  const _SortOrderSheet({
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final String selected;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 28,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sort Order',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            _SortOption(
              value: 'default',
              selected: selected,
              title: 'Default',
              subtitle: 'Sort all items by recency',
              accent: accent,
              onSelected: onSelected,
            ),
            const SizedBox(height: 8),
            _SortOption(
              value: 'streaming',
              selected: selected,
              title: 'Streaming Style',
              subtitle: 'Released items first; upcoming at the end',
              accent: accent,
              onSelected: onSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.value,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onSelected,
  });

  final String value;
  final String selected;
  final String title;
  final String subtitle;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = value == selected;
    return Material(
      color: isSelected ? Colors.white.withOpacity(0.09) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? accent.withOpacity(0.34) : Colors.transparent,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13.5,
                        height: 1.22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? accent : Colors.white.withOpacity(0.06),
                  border: Border.all(
                    color: isSelected ? accent : Colors.white.withOpacity(0.14),
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.background,
                        size: 20,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sortOrderLabel(String value) {
  switch (value) {
    case 'streaming':
      return 'Streaming Style';
    case 'default':
    default:
      return 'Default';
  }
}
