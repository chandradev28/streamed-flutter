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
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 130),
                children: <Widget>[
                  const _LayoutTitle(title: 'Layout'),
                  const SizedBox(height: 24),
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
                        onTap: _openContinueWatching,
                      ),
                      _NavigationRow(
                        icon: Icons.tune_rounded,
                        title: 'Poster Card Style',
                        subtitle: 'Tune card width and corner radius.',
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
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 130),
                children: <Widget>[
                  const _LayoutTitle(title: 'Continue\nWatching'),
                  const SizedBox(height: 22),
                  const _SectionLabel('VISIBILITY'),
                  _SettingsCard(
                    children: <Widget>[
                      _ToggleRow(
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
                  const SizedBox(height: 16),
                  const _SectionLabel('Poster Card Style'),
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
                  const SizedBox(height: 22),
                  const _SectionLabel('UP NEXT BEHAVIOR'),
                  _SettingsCard(
                    children: <Widget>[
                      _ToggleRow(
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
                      _ToggleRow(
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
                      _ToggleRow(
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
                      _ToggleRow(
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
                  const SizedBox(height: 22),
                  const _SectionLabel('ON LAUNCH'),
                  _SettingsCard(
                    children: <Widget>[
                      _ToggleRow(
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
                  const SizedBox(height: 22),
                  const _SectionLabel('SORT ORDER'),
                  _SettingsCard(
                    children: <Widget>[
                      _NavigationRow(
                        title: 'Sort Order',
                        subtitle: _sortOrderLabel(
                            _settings.continueWatchingSortOrder),
                        onTap: _showSortOrderSheet,
                      ),
                    ],
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
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 130),
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      const Expanded(
                        child: _LayoutTitle(title: 'Poster Card\nStyle'),
                      ),
                      TextButton(
                        onPressed: _reset,
                        child: Text(
                          'Reset to Default',
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('Poster Card Style'),
                  _SettingsCard(
                    children: <Widget>[
                      const Text(
                        'Tune card width and corner radius.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Live Preview',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
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
                          const SizedBox(width: 26),
                          Expanded(
                            child: Text(
                              'Width: ${width.round()}dp\nCorner radius: ${radius.round()}dp\nHeight: ${height.round()}dp',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Divider(color: Colors.white.withOpacity(0.08)),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 22),
                      _ToggleRow(
                        title: 'Landscape Posters',
                        value: _settings.posterLandscapeEnabled,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(posterLandscapeEnabled: value),
                        ),
                      ),
                      _ToggleRow(
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
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 18,
          childAspectRatio: 0.92,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: LayoutOptions.themes.map((LayoutThemeOption option) {
            final bool selected = option.id == settings.layoutTheme;
            return GestureDetector(
              onTap: () => onSelected(option.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
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
                      width: 54,
                      height: 54,
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
                    const SizedBox(height: 9),
                    Text(
                      option.label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
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
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 40,
              height: 0.96,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
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
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: icon == null
          ? null
          : Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.text),
            ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, height: 1.25),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
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
      padding: const EdgeInsets.symmetric(vertical: 7),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      height: 1.28,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
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
        height: 158,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent.withOpacity(0.85) : AppColors.border,
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
                color: selected ? accent : AppColors.textMuted,
                size: 20,
              ),
            ),
            const Spacer(),
            Icon(icon, color: AppColors.textMuted, size: 42),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                height: 1.2,
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
        return ChoiceChip(
          label: Text(labelFor(value)),
          selected: isSelected,
          selectedColor: accent.withOpacity(0.25),
          backgroundColor: Colors.transparent,
          side: BorderSide(
            color: isSelected ? accent.withOpacity(0.55) : AppColors.border,
          ),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.text : AppColors.textMuted,
            fontWeight: FontWeight.w800,
          ),
          onSelected: (_) => onSelected(value),
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
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Sort Order',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _SortOption(
            value: 'default',
            selected: selected,
            title: 'Default',
            subtitle: 'Sort all items by recency',
            accent: accent,
            onSelected: onSelected,
          ),
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
    return ListTile(
      onTap: () => onSelected(value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: isSelected ? Colors.white.withOpacity(0.12) : null,
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: accent)
          : const SizedBox.shrink(),
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
