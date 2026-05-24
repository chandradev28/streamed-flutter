import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/stremio_addons_service.dart';
import '../theme/app_colors.dart';

class AddonsScreen extends StatefulWidget {
  AddonsScreen({
    super.key,
    StremioAddonsService? addonsService,
    AppSettingsRepository? settingsRepository,
  })  : addonsService = addonsService ?? StremioAddonsService(),
        settingsRepository = settingsRepository ?? AppSettingsRepository();

  final StremioAddonsService addonsService;
  final AppSettingsRepository settingsRepository;

  @override
  State<AddonsScreen> createState() => _AddonsScreenState();
}

class _AddonsScreenState extends State<AddonsScreen> {
  final TextEditingController _urlController = TextEditingController();
  List<AddonManifest> _addons = const <AddonManifest>[];
  bool _loading = true;
  bool _installing = false;
  bool _useAddons = false;

  int get _streamAddonCount =>
      _addons.where((AddonManifest addon) => addon.hasStreamResource).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      widget.addonsService.getInstalledAddons(),
      widget.settingsRepository.getUseAddons(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _addons = results[0] as List<AddonManifest>;
      _useAddons = results[1] as bool;
      _loading = false;
    });
  }

  Future<void> _toggleUseAddons(bool value) async {
    await widget.settingsRepository.saveUseAddons(value);
    if (!mounted) {
      return;
    }

    setState(() {
      _useAddons = value;
    });
  }

  Future<void> _installAddon() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) {
      return;
    }

    setState(() {
      _installing = true;
    });

    try {
      final AddonManifest addon = await widget.addonsService.installAddon(url);
      _urlController.clear();
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${addon.name} installed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _installing = false;
        });
      }
    }
  }

  Future<void> _removeAddon(AddonManifest addon) async {
    await widget.addonsService.removeAddon(addon.id);
    await _load();
  }

  Future<void> _toggleAddon(AddonManifest addon, bool value) async {
    await widget.addonsService.setAddonEnabled(addon.id, value);
    await _load();
  }

  Future<void> _refreshAddon(AddonManifest addon) async {
    try {
      final AddonManifest? refreshed =
          await widget.addonsService.refreshAddon(addon.id);
      await _load();
      if (!mounted || refreshed == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${refreshed.name} refreshed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Addons'),
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
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _useAddons
                                ? 'Using Torrentio + addons'
                                : 'Using Torrentio only',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _useAddons
                                ? 'Torboxers will merge ${_streamAddonCount == 0 ? 'no installed stream addons yet' : '$_streamAddonCount stream addon${_streamAddonCount == 1 ? '' : 's'}'} into search.'
                                : 'Only the built-in Torrentio path is active right now.',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _useAddons,
                      onChanged: _toggleUseAddons,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
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
                      'Install addon',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Paste a full Stremio manifest URL. `https://.../manifest.json`, configure links with query params, and `stremio://...` links are all supported.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlController,
                      style: const TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: 'https://.../manifest.json or stremio://...',
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
                      onPressed: _installing ? null : _installAddon,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.text,
                        foregroundColor: AppColors.background,
                      ),
                      child: Text(_installing ? 'Installing...' : 'Install'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _OverviewMetric(
                        value: _addons.length.toString(),
                        label: 'Installed',
                      ),
                    ),
                    Expanded(
                      child: _OverviewMetric(
                        value: _streamAddonCount.toString(),
                        label: 'Stream ready',
                      ),
                    ),
                    Expanded(
                      child: _OverviewMetric(
                        value: _addons
                            .where((AddonManifest addon) =>
                                addon.configurationRequired)
                            .length
                            .toString(),
                        label: 'Need setup',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.text),
                  ),
                )
              else if (_addons.isEmpty)
                const _EmptyAddonsState()
              else
                ..._addons.map(
                  (AddonManifest addon) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
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
                                  addon.name,
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Switch(
                                value: addon.enabled,
                                onChanged: (bool value) =>
                                    _toggleAddon(addon, value),
                              ),
                              IconButton(
                                onPressed: () => _refreshAddon(addon),
                                icon: const Icon(
                                  Icons.refresh,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removeAddon(addon),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFFCA5A5),
                                ),
                              ),
                            ],
                          ),
                          if ((addon.description ?? '').isNotEmpty) ...<Widget>[
                            Text(
                              addon.description!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _AddonMetaChip(label: addon.version),
                              if (addon.hasStreamResource)
                                const _AddonMetaChip(label: 'Streams'),
                              if (addon.hasSubtitleResource)
                                const _AddonMetaChip(label: 'Subtitles'),
                              _AddonMetaChip(
                                label: addon.enabled ? 'Enabled' : 'Disabled',
                              ),
                              _AddonMetaChip(
                                label: addon.resources.isEmpty
                                    ? '0 resources'
                                    : '${addon.resources.length} resources',
                              ),
                              if (addon.supportedMediaTypes.isNotEmpty)
                                _AddonMetaChip(
                                  label: addon.supportedMediaTypes.join(' • '),
                                ),
                              if (addon.configurable)
                                const _AddonMetaChip(label: 'Configurable'),
                              if (addon.configurationRequired)
                                const _AddonMetaChip(label: 'Needs setup'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            addon.originalUrl,
                            style: const TextStyle(
                              color: AppColors.textSubtle,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddonMetaChip extends StatelessWidget {
  const _AddonMetaChip({required this.label});

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

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _EmptyAddonsState extends StatelessWidget {
  const _EmptyAddonsState();

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
          Icon(Icons.extension_outlined, color: AppColors.textMuted, size: 36),
          SizedBox(height: 12),
          Text(
            'No addons installed yet.',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Paste a Stremio manifest URL above and the Torboxers search tab can merge those streams when addon mode is enabled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
