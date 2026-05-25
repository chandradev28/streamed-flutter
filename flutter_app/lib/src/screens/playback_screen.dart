import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';

class PlaybackScreen extends StatefulWidget {
  PlaybackScreen({
    super.key,
    AppSettingsRepository? settingsRepository,
  }) : settingsRepository = settingsRepository ?? AppSettingsRepository();

  final AppSettingsRepository settingsRepository;

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  final TextEditingController _subtitleLanguageController =
      TextEditingController();
  final TextEditingController _secondarySubtitleLanguageController =
      TextEditingController();
  final TextEditingController _audioLanguageController =
      TextEditingController();

  AppSettings _settings = const AppSettings();
  bool _loading = true;

  Color get _accent => LayoutOptions.accentFor(_settings);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subtitleLanguageController.dispose();
    _secondarySubtitleLanguageController.dispose();
    _audioLanguageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    _syncControllers(settings);
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  void _syncControllers(AppSettings settings) {
    _subtitleLanguageController.text =
        settings.playbackPreferredSubtitleLanguage;
    _secondarySubtitleLanguageController.text =
        settings.playbackSecondarySubtitleLanguage;
    _audioLanguageController.text = settings.playbackPreferredAudioLanguage;
  }

  Future<void> _save(AppSettings settings) async {
    setState(() {
      _settings = settings;
    });
    await widget.settingsRepository.saveSettings(settings);
  }

  Future<void> _saveLanguageFields() async {
    await _save(
      _settings.copyWith(
        playbackPreferredSubtitleLanguage:
            _subtitleLanguageController.text.trim().toLowerCase(),
        playbackSecondarySubtitleLanguage:
            _secondarySubtitleLanguageController.text.trim().toLowerCase(),
        playbackPreferredAudioLanguage:
            _audioLanguageController.text.trim().toLowerCase(),
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Playback language preferences saved.')),
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
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 130),
                children: <Widget>[
                  _PlaybackTitle(accent: _accent),
                  const SizedBox(height: 24),
                  const _SectionLabel('PLAYER'),
                  _SettingsCard(
                    children: <Widget>[
                      _ToggleRow(
                        title: 'Auto-play stream',
                        subtitle:
                            'Start playback immediately after a stream opens.',
                        value: _settings.playbackAutoPlay,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(playbackAutoPlay: value),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Prefer external player',
                        subtitle:
                            'Open resolved streams in VLC or another video app first.',
                        value: _settings.playbackPreferExternalPlayer,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            playbackPreferExternalPlayer: value,
                          ),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Resume last position',
                        subtitle:
                            'Continue from saved progress when opening a title.',
                        value: _settings.playbackResumeEnabled,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(playbackResumeEnabled: value),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Save progress',
                        subtitle:
                            'Update Continue Watching while the video plays.',
                        value: _settings.playbackSaveProgress,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(playbackSaveProgress: value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('CONTROLS'),
                  _SettingsCard(
                    children: <Widget>[
                      _ChoiceRow<int>(
                        title: 'Skip amount',
                        subtitle: 'Back and forward button duration.',
                        value: _settings.playbackSkipSeconds,
                        values: const <int>[5, 10, 15, 30],
                        labelFor: (int value) => '${value}s',
                        accent: _accent,
                        onSelected: (int value) => _save(
                          _settings.copyWith(playbackSkipSeconds: value),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ToggleRow(
                        title: 'Hold to speed up',
                        subtitle:
                            'Long-press the player to temporarily play faster.',
                        value: _settings.playbackHoldToSpeed,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(playbackHoldToSpeed: value),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Show speed controls',
                        subtitle: 'Expose the Speed button inside the player.',
                        value: _settings.playbackSpeedControls,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(playbackSpeedControls: value),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ChoiceRow<double>(
                        title: 'Default speed',
                        subtitle: 'Applied when a stream starts.',
                        value: _settings.playbackDefaultSpeed,
                        values: const <double>[0.75, 1.0, 1.25, 1.5, 2.0],
                        labelFor: _speedLabel,
                        accent: _accent,
                        onSelected: (double value) => _save(
                          _settings.copyWith(playbackDefaultSpeed: value),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ChoiceRow<double>(
                        title: 'Hold speed',
                        subtitle: 'Temporary speed while long-pressing.',
                        value: _settings.playbackHoldSpeed,
                        values: const <double>[1.5, 2.0, 2.5, 3.0],
                        labelFor: _speedLabel,
                        accent: _accent,
                        onSelected: (double value) => _save(
                          _settings.copyWith(playbackHoldSpeed: value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('PLAYER BUTTONS'),
                  _SettingsCard(
                    children: <Widget>[
                      _ToggleRow(
                        title: 'Files / episodes',
                        value: _settings.playbackShowFilesButton,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(playbackShowFilesButton: value),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Subtitles',
                        value: _settings.playbackShowSubtitlesButton,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            playbackShowSubtitlesButton: value,
                          ),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Audio',
                        value: _settings.playbackShowAudioButton,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(playbackShowAudioButton: value),
                        ),
                      ),
                      _ToggleRow(
                        title: 'External player',
                        value: _settings.playbackShowExternalButton,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            playbackShowExternalButton: value,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('SUBTITLE & AUDIO'),
                  _SettingsCard(
                    children: <Widget>[
                      const Text(
                        'Use short language codes like en, hi, ja, es. Track selection depends on what the stream exposes.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LanguageField(
                        label: 'Preferred subtitle language',
                        controller: _subtitleLanguageController,
                      ),
                      const SizedBox(height: 12),
                      _LanguageField(
                        label: 'Secondary subtitle language',
                        controller: _secondarySubtitleLanguageController,
                      ),
                      const SizedBox(height: 12),
                      _LanguageField(
                        label: 'Preferred audio language',
                        controller: _audioLanguageController,
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          onPressed: _saveLanguageFields,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: AppColors.background,
                          ),
                          child: const Text('Save languages'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('NEXT EPISODE'),
                  _SettingsCard(
                    children: <Widget>[
                      _ToggleRow(
                        title: 'Auto-play next episode',
                        subtitle:
                            'When parsed episodes exist, jump to the next file near the end.',
                        value: _settings.playbackAutoPlayNextEpisode,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            playbackAutoPlayNextEpisode: value,
                          ),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Allow next season',
                        subtitle:
                            'Continue across season groups when the current season ends.',
                        value: _settings.playbackBingeGroupNextEpisode,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            playbackBingeGroupNextEpisode: value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Next episode threshold: ${_settings.playbackNextEpisodeThreshold}%',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Slider(
                        value:
                            _settings.playbackNextEpisodeThreshold.toDouble(),
                        min: 70,
                        max: 98,
                        divisions: 28,
                        activeColor: _accent,
                        inactiveColor: Colors.white24,
                        label:
                            '${_settings.playbackNextEpisodeThreshold.round()}%',
                        onChanged: (double value) => _save(
                          _settings.copyWith(
                            playbackNextEpisodeThreshold: value.round(),
                          ),
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

class _PlaybackTitle extends StatelessWidget {
  const _PlaybackTitle({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_rounded, color: accent),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Playback',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 40,
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
          fontSize: 13,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 18),
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

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.accent,
    required this.onSelected,
  });

  final String title;
  final String subtitle;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final Color accent;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: values.map((T candidate) {
            final bool selected = candidate == value;
            return Material(
              color: selected
                  ? accent.withOpacity(0.28)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onSelected(candidate),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          selected ? accent.withOpacity(0.7) : AppColors.border,
                    ),
                  ),
                  child: Text(
                    labelFor(candidate),
                    style: TextStyle(
                      color: selected ? AppColors.text : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

class _LanguageField extends StatelessWidget {
  const _LanguageField({
    required this.label,
    required this.controller,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintText: 'en',
        hintStyle: const TextStyle(color: AppColors.textSubtle),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
    );
  }
}

String _speedLabel(double value) {
  if (value == value.roundToDouble()) {
    return '${value.toInt()}x';
  }
  return '${value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}x';
}
