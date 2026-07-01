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

  Future<void> _showLanguagePicker({
    required String title,
    required String value,
    required String noneLabel,
    required ValueChanged<String> onSelected,
  }) async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (BuildContext context) {
        return _LanguagePickerSheet(
          title: title,
          value: value,
          noneLabel: noneLabel,
          accent: _accent,
        );
      },
    );
    if (selected == null) {
      return;
    }
    onSelected(selected);
  }

  Future<void> _showSubtitleStartupPicker() async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (BuildContext context) {
        return _SimpleChoiceSheet(
          title: 'Addon Subtitle Startup',
          value: _settings.playbackAddonSubtitleStartup,
          accent: _accent,
          choices: const <_ChoiceOption>[
            _ChoiceOption(
              value: 'all',
              title: 'All subtitles',
              subtitle: 'Show every subtitle track exposed by the stream.',
            ),
            _ChoiceOption(
              value: 'preferred',
              title: 'Preferred only',
              subtitle: 'Start with your preferred subtitle language.',
            ),
            _ChoiceOption(
              value: 'off',
              title: 'Off',
              subtitle: 'Keep subtitles disabled when playback starts.',
            ),
          ],
        );
      },
    );
    if (selected == null) {
      return;
    }
    await _save(_settings.copyWith(playbackAddonSubtitleStartup: selected));
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
                      _OptionRow(
                        title: 'Preferred Audio Language',
                        value: _languageLabel(
                          _settings.playbackPreferredAudioLanguage,
                          noneLabel: 'Device language',
                        ),
                        onTap: () => _showLanguagePicker(
                          title: 'Preferred Audio Language',
                          value: _settings.playbackPreferredAudioLanguage,
                          noneLabel: 'Device language',
                          onSelected: (String value) => _save(
                            _settings.copyWith(
                              playbackPreferredAudioLanguage: value,
                            ),
                          ),
                        ),
                      ),
                      _OptionRow(
                        title: 'Secondary Audio Language',
                        value: _languageLabel(
                          _settings.playbackSecondaryAudioLanguage,
                          noneLabel: 'None',
                        ),
                        onTap: () => _showLanguagePicker(
                          title: 'Secondary Audio Language',
                          value: _settings.playbackSecondaryAudioLanguage,
                          noneLabel: 'None',
                          onSelected: (String value) => _save(
                            _settings.copyWith(
                              playbackSecondaryAudioLanguage: value,
                            ),
                          ),
                        ),
                      ),
                      _OptionRow(
                        title: 'Preferred Subtitle Language',
                        value: _languageLabel(
                          _settings.playbackPreferredSubtitleLanguage,
                          noneLabel: 'None',
                        ),
                        onTap: () => _showLanguagePicker(
                          title: 'Preferred Subtitle Language',
                          value: _settings.playbackPreferredSubtitleLanguage,
                          noneLabel: 'None',
                          onSelected: (String value) => _save(
                            _settings.copyWith(
                              playbackPreferredSubtitleLanguage: value,
                            ),
                          ),
                        ),
                      ),
                      _OptionRow(
                        title: 'Secondary Subtitle Language',
                        value: _languageLabel(
                          _settings.playbackSecondarySubtitleLanguage,
                          noneLabel: 'None',
                        ),
                        onTap: () => _showLanguagePicker(
                          title: 'Secondary Subtitle Language',
                          value: _settings.playbackSecondarySubtitleLanguage,
                          noneLabel: 'None',
                          onSelected: (String value) => _save(
                            _settings.copyWith(
                              playbackSecondarySubtitleLanguage: value,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _ToggleRow(
                        title: 'Use Forced Subtitles',
                        subtitle:
                            'Prefer forced subtitles when they match your subtitle language.',
                        value: _settings.playbackUseForcedSubtitles,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            playbackUseForcedSubtitles: value,
                          ),
                        ),
                      ),
                      _ToggleRow(
                        title: 'Show Only Preferred Languages',
                        subtitle:
                            'Only list subtitle tracks matching your preferred languages.',
                        value: _settings.playbackShowOnlyPreferredLanguages,
                        accent: _accent,
                        onChanged: (bool value) => _save(
                          _settings.copyWith(
                            playbackShowOnlyPreferredLanguages: value,
                          ),
                        ),
                      ),
                      _OptionRow(
                        title: 'Addon Subtitle Startup',
                        value: _subtitleStartupLabel(
                          _settings.playbackAddonSubtitleStartup,
                        ),
                        onTap: _showSubtitleStartupPicker,
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

String _speedLabel(double value) {
  if (value == value.roundToDouble()) {
    return '${value.toInt()}x';
  }
  return '${value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}x';
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
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
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({
    required this.title,
    required this.value,
    required this.noneLabel,
    required this.accent,
  });

  final String title;
  final String value;
  final String noneLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _LanguageTile(
            option: _LanguageOption('', noneLabel),
            selected: value.isEmpty,
            accent: accent,
          ),
          ..._languageOptions.map(
            (_LanguageOption option) => _LanguageTile(
              option: option,
              selected: option.code == value,
              accent: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.option,
    required this.selected,
    required this.accent,
  });

  final _LanguageOption option;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        option.label,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: option.code.isEmpty
          ? null
          : Text(
              option.code,
              style: const TextStyle(color: AppColors.textMuted),
            ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: accent)
          : const SizedBox(width: 24),
      onTap: () => Navigator.of(context).pop(option.code),
    );
  }
}

class _SimpleChoiceSheet extends StatelessWidget {
  const _SimpleChoiceSheet({
    required this.title,
    required this.value,
    required this.choices,
    required this.accent,
  });

  final String title;
  final String value;
  final List<_ChoiceOption> choices;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...choices.map(
            (_ChoiceOption option) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                option.title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                option.subtitle,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              trailing: option.value == value
                  ? Icon(Icons.check_rounded, color: accent)
                  : const SizedBox(width: 24),
              onTap: () => Navigator.of(context).pop(option.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption(this.code, this.label);

  final String code;
  final String label;
}

class _ChoiceOption {
  const _ChoiceOption({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final String value;
  final String title;
  final String subtitle;
}

const List<_LanguageOption> _languageOptions = <_LanguageOption>[
  _LanguageOption('en', 'English'),
  _LanguageOption('hi', 'Hindi'),
  _LanguageOption('ja', 'Japanese'),
  _LanguageOption('es', 'Spanish'),
  _LanguageOption('fr', 'French'),
  _LanguageOption('de', 'German'),
  _LanguageOption('it', 'Italian'),
  _LanguageOption('pt', 'Portuguese'),
  _LanguageOption('ru', 'Russian'),
  _LanguageOption('ko', 'Korean'),
  _LanguageOption('zh', 'Chinese'),
  _LanguageOption('ar', 'Arabic'),
  _LanguageOption('tr', 'Turkish'),
  _LanguageOption('id', 'Indonesian'),
  _LanguageOption('bn', 'Bengali'),
];

String _languageLabel(String code, {required String noneLabel}) {
  final String normalized = code.trim().toLowerCase();
  if (normalized.isEmpty) {
    return noneLabel;
  }
  for (final _LanguageOption option in _languageOptions) {
    if (option.code == normalized) {
      return option.label;
    }
  }
  return normalized;
}

String _subtitleStartupLabel(String value) {
  switch (value) {
    case 'preferred':
      return 'Preferred only';
    case 'off':
      return 'Off';
    case 'all':
    default:
      return 'All subtitles';
  }
}
