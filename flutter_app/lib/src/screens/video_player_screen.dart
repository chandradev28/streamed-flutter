import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/torbox_models.dart';
import '../models/watch_history_item.dart';
import '../services/episode_parser.dart';
import '../services/torbox_api_service.dart';
import '../services/watch_history_repository.dart';
import '../theme/app_colors.dart';

class VideoPlayerScreen extends StatefulWidget {
  VideoPlayerScreen({
    super.key,
    required this.title,
    this.posterUrl,
    this.tmdbId,
    this.mediaType,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeName,
    this.torrentHash,
    this.torrentId,
    this.initialVideoUrl,
    this.initialFiles = const <TorBoxTorrentFile>[],
    this.initialFileId,
    this.initialFileIndex,
    this.initialFileName,
    this.startPositionMs,
    this.provider,
    this.streamHeaders = const <String, String>{},
    TorBoxApiService? torBoxApiService,
    ContinueWatchingRepository? watchHistoryRepository,
  })  : torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        watchHistoryRepository =
            watchHistoryRepository ?? WatchHistoryRepository();

  final String title;
  final String? posterUrl;
  final int? tmdbId;
  final String? mediaType;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;
  final String? torrentHash;
  final int? torrentId;
  final String? initialVideoUrl;
  final List<TorBoxTorrentFile> initialFiles;
  final int? initialFileId;
  final int? initialFileIndex;
  final String? initialFileName;
  final int? startPositionMs;
  final String? provider;
  final Map<String, String> streamHeaders;
  final TorBoxApiService torBoxApiService;
  final ContinueWatchingRepository watchHistoryRepository;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  List<TorBoxTorrentFile> _files = const <TorBoxTorrentFile>[];
  String? _resolvedUrl;
  int? _activeFileId;
  Timer? _progressTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = true;
  bool _saving = false;
  bool _initialized = false;
  bool _showControls = true;
  String? _error;
  _PlaybackIssue? _playbackIssue;
  int _lastPersistedSecond = -1;

  @override
  void initState() {
    super.initState();
    _files = widget.initialFiles;
    _resolvedUrl = widget.initialVideoUrl;
    _activeFileId = widget.initialFileId;
    _load();
  }

  Future<void> _load() async {
    if (_resolvedUrl != null && _resolvedUrl!.isNotEmpty) {
      await _openResolvedMedia(_resolvedUrl!);
      return;
    }

    final int? torrentId = widget.torrentId;
    if (torrentId == null) {
      setState(() {
        _loading = false;
        _error = 'No direct stream URL or TorBox torrent was provided.';
        _playbackIssue = const _PlaybackIssue(
          title: 'Nothing to play yet',
          body:
              'This screen needs either a direct stream URL or a TorBox torrent.',
          showExternalActions: false,
        );
      });
      return;
    }

    try {
      final List<TorBoxTorrentFile> files = _files.isNotEmpty
          ? _files
          : await widget.torBoxApiService.getTorrentFiles(torrentId);
      if (!mounted) {
        return;
      }

      final int? fileId = _preferredFileId(files);
      setState(() {
        _files = files;
        _activeFileId = fileId;
      });

      if (fileId != null) {
        await _resolveFile(fileId);
      } else if (mounted) {
        setState(() {
          _loading = false;
          _error = 'This torrent does not expose playable files yet.';
          _playbackIssue = const _PlaybackIssue(
            title: 'No playable files found',
            body:
                'TorBox returned the torrent, but it does not expose a playable video file yet. Refresh the library and try again.',
            showExternalActions: false,
          );
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _friendlyError(error);
        _playbackIssue = _describePlaybackIssue(error);
      });
    }
  }

  int? _preferredFileId(List<TorBoxTorrentFile> files) {
    if (files.isEmpty) {
      return null;
    }

    final int? activeFileId = _activeFileId;
    if (activeFileId != null &&
        files.any((TorBoxTorrentFile file) => file.id == activeFileId)) {
      return activeFileId;
    }

    final int? initialFileId = widget.initialFileId;
    if (initialFileId != null &&
        files.any((TorBoxTorrentFile file) => file.id == initialFileId)) {
      return initialFileId;
    }

    final int? initialFileIndex = widget.initialFileIndex;
    if (initialFileIndex != null &&
        initialFileIndex >= 0 &&
        initialFileIndex < files.length) {
      return files[initialFileIndex].id;
    }

    final String? initialFileName = widget.initialFileName;
    if (initialFileName != null && initialFileName.trim().isNotEmpty) {
      final String normalizedTarget = _normalizeFileName(initialFileName);
      for (final TorBoxTorrentFile file in files) {
        if (_normalizeFileName(file.name) == normalizedTarget ||
            _normalizeFileName(file.displayName) == normalizedTarget) {
          return file.id;
        }
      }
    }

    if (widget.mediaType == 'tv' &&
        widget.seasonNumber != null &&
        widget.episodeNumber != null) {
      final List<SeasonFileGroup> seasons = parseSeasonPack(files);
      for (final SeasonFileGroup season in seasons) {
        for (final ParsedEpisodeFile episode in season.episodes) {
          if (episode.season == widget.seasonNumber &&
              episode.episode == widget.episodeNumber &&
              episode.originalIndex >= 0 &&
              episode.originalIndex < files.length) {
            return files[episode.originalIndex].id;
          }
        }
      }
    }

    final List<int> videoIndices = getAllVideoFiles(files);
    if (videoIndices.isNotEmpty) {
      final List<TorBoxTorrentFile> videoFiles = videoIndices
          .map((int index) => files[index])
          .toList(growable: false)
        ..sort(_comparePlaybackPreference);
      return videoFiles.first.id;
    }

    return files.first.id;
  }

  String _normalizeFileName(String value) {
    return value.split(RegExp(r'[/\\]')).last.trim().toLowerCase();
  }

  int _comparePlaybackPreference(
    TorBoxTorrentFile a,
    TorBoxTorrentFile b,
  ) {
    final int codecComparison =
        _codecPreferenceScore(a).compareTo(_codecPreferenceScore(b));
    if (codecComparison != 0) {
      return codecComparison;
    }
    return b.size.compareTo(a.size);
  }

  int _codecPreferenceScore(TorBoxTorrentFile file) {
    final String name = file.displayName.toLowerCase();
    if (_looksLikeHevc(name)) {
      return 10;
    }
    if (RegExp(r'(h\.?264|x264|avc)', caseSensitive: false).hasMatch(name)) {
      return 0;
    }
    return 2;
  }

  bool _looksLikeHevc(String value) {
    return RegExp(
      r'(hevc|h\.?265|x265|10bit|10-bit|hi10|hvc1)',
      caseSensitive: false,
    ).hasMatch(value);
  }

  Future<void> _resolveFile(int fileId) async {
    final int? torrentId = widget.torrentId;
    if (torrentId == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _playbackIssue = null;
      _activeFileId = fileId;
    });

    final String? url = await widget.torBoxApiService.getQuickStreamUrl(
      torrentId,
      fileId,
    );
    if (!mounted) {
      return;
    }

    if (url == null || url.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Could not resolve a stream URL for this file.';
        _playbackIssue = const _PlaybackIssue(
          title: 'Could not get stream link',
          body:
              'TorBox did not return a playable link for this file yet. Try refreshing the library or choose another file.',
          showExternalActions: false,
        );
      });
      return;
    }

    setState(() {
      _resolvedUrl = url;
    });

    await _openResolvedMedia(url);
  }

  Future<void> _openResolvedMedia(String url) async {
    VideoPlayerController? nextController;
    try {
      final VideoPlayerController? previousController = _controller;
      setState(() {
        _controller = null;
        _loading = true;
        _error = null;
        _playbackIssue = null;
        _initialized = false;
        _position = Duration.zero;
        _duration = Duration.zero;
      });

      _progressTimer?.cancel();
      previousController?.removeListener(_handleControllerTick);
      await previousController?.dispose();

      nextController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: widget.streamHeaders,
      );
      await nextController.initialize();
      await nextController.setLooping(false);
      await nextController.play();

      if (widget.startPositionMs != null && widget.startPositionMs! > 0) {
        await nextController.seekTo(
          Duration(milliseconds: widget.startPositionMs!),
        );
      }

      nextController.addListener(_handleControllerTick);
      _progressTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _handleControllerTick(),
      );

      if (!mounted) {
        await nextController.dispose();
        return;
      }

      setState(() {
        _controller = nextController;
        _initialized = true;
        _loading = false;
        _duration = nextController!.value.duration;
        _position = nextController.value.position;
      });
    } catch (error) {
      await nextController?.dispose();
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _initialized = false;
        _error = _friendlyError(error);
        _playbackIssue = _describePlaybackIssue(error);
      });
    }
  }

  void _handleControllerTick() {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !mounted) {
      return;
    }

    final VideoPlayerValue value = controller.value;
    setState(() {
      _position = value.position;
      _duration = value.duration;
    });

    if (value.hasError) {
      setState(() {
        final String raw = value.errorDescription ?? 'Video playback error.';
        _error = _friendlyError(raw);
        _playbackIssue = _describePlaybackIssue(raw);
      });
    }

    if (value.isCompleted) {
      unawaited(_persistProgress(forceCompleted: true));
      return;
    }

    if (value.position.inSeconds >= 10 &&
        value.position.inSeconds != _lastPersistedSecond &&
        value.position.inSeconds % 10 == 0) {
      _lastPersistedSecond = value.position.inSeconds;
      unawaited(_persistProgress());
    }
  }

  Future<void> _persistProgress({bool forceCompleted = false}) async {
    final int? tmdbId = widget.tmdbId;
    final String? mediaType = widget.mediaType;
    if (tmdbId == null || mediaType == null) {
      return;
    }

    final Duration duration = _duration;
    if (duration <= Duration.zero) {
      return;
    }

    final double progress = forceCompleted
        ? 100
        : ((_position.inMilliseconds / duration.inMilliseconds) * 100)
            .clamp(0, 100);

    if (!forceCompleted &&
        _position.inSeconds < 10 &&
        (widget.startPositionMs ?? 0) <= 0) {
      return;
    }

    if (mounted) {
      setState(() {
        _saving = true;
      });
    }

    final String id = <String>[
      tmdbId.toString(),
      mediaType,
      if (widget.seasonNumber != null) 's${widget.seasonNumber}',
      if (widget.episodeNumber != null) 'e${widget.episodeNumber}',
    ].join('_');

    await widget.watchHistoryRepository.saveProgress(
      WatchHistoryItem(
        id: id,
        tmdbId: tmdbId,
        mediaType: mediaType,
        title: widget.title,
        posterPath: widget.posterUrl,
        backdropPath: widget.posterUrl,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
        episodeName: widget.episodeName,
        progress: progress,
        currentTime:
            forceCompleted ? duration.inMilliseconds : _position.inMilliseconds,
        duration: duration.inMilliseconds,
        lastWatched: DateTime.now().millisecondsSinceEpoch,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });
  }

  Future<void> _togglePlayPause() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _seekRelative(int seconds) async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || controller.value.duration <= Duration.zero) {
      return;
    }

    final Duration target =
        controller.value.position + Duration(seconds: seconds);
    final Duration clamped = target < Duration.zero
        ? Duration.zero
        : (target > controller.value.duration
            ? controller.value.duration
            : target);
    await controller.seekTo(clamped);
  }

  Future<void> _openExternalPlayer() async {
    final String? url = _resolvedUrl;
    if (url == null || url.isEmpty) {
      return;
    }

    final Uri uri = Uri.parse(url);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }

    await _copyStreamUrl();
  }

  Future<void> _copyStreamUrl() async {
    final String? url = _resolvedUrl;
    if (url == null || url.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Stream URL copied for an external player.')),
    );
  }

  Future<void> _retryActiveFile() async {
    final int? activeFileId = _activeFileId;
    final String? resolvedUrl = _resolvedUrl;
    if (activeFileId != null) {
      await _resolveFile(activeFileId);
      return;
    }
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      await _openResolvedMedia(resolvedUrl);
    }
  }

  String _friendlyError(Object error) {
    final _PlaybackIssue issue = _describePlaybackIssue(error);
    return '${issue.title}. ${issue.body}';
  }

  _PlaybackIssue _describePlaybackIssue(Object error) {
    final String raw = error.toString();
    final TorBoxTorrentFile? activeFile = _activeFile;
    final bool hevcFile =
        activeFile != null && _looksLikeHevc(activeFile.displayName);
    final bool codecError = RegExp(
      r'(MediaCodecVideoRenderer|NO_EXCEEDS_CAPABILITIES|format_supported|video/hevc|hvc1|decoder|ExoPlaybackException)',
      caseSensitive: false,
    ).hasMatch(raw);

    if (codecError || hevcFile) {
      return _PlaybackIssue(
        title: 'This file is not supported by this device',
        body:
            'The selected video looks like HEVC/x265. Many Android phones cannot decode that inside Flutter. Choose an H.264/x264 file if available, or open the TorBox stream in an external player like VLC.',
        showExternalActions: true,
        rawDetails: raw,
      );
    }

    if (raw.contains('Source error') || raw.contains('HTTP')) {
      return _PlaybackIssue(
        title: 'Could not stream this file',
        body:
            'The TorBox link may have expired or the file is not ready yet. Try again, refresh the library, or choose another file.',
        showExternalActions: true,
        rawDetails: raw,
      );
    }

    return _PlaybackIssue(
      title: 'Playback failed',
      body:
          'The player could not start this stream. Try another file or open the stream in an external player.',
      showExternalActions: true,
      rawDetails: raw,
    );
  }

  TorBoxTorrentFile? get _activeFile =>
      _files.cast<TorBoxTorrentFile?>().firstWhere(
            (TorBoxTorrentFile? file) => file?.id == _activeFileId,
            orElse: () => null,
          );

  void _showFileSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: _files
                .map(
                  (TorBoxTorrentFile file) => ListTile(
                    title: Text(
                      file.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.text),
                    ),
                    subtitle: Text(
                      _formatBytes(file.size),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    trailing: file.id == _activeFileId
                        ? const Icon(Icons.check, color: AppColors.text)
                        : null,
                    onTap: () async {
                      Navigator.of(context).maybePop();
                      await _resolveFile(file.id);
                    },
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_persistProgress());
    _progressTimer?.cancel();
    _controller?.removeListener(_handleControllerTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;
    final bool isPlaying = controller?.value.isPlaying ?? false;
    final bool isBuffering = controller?.value.isBuffering ?? false;
    final double progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0, 1)
        : 0;
    final TorBoxTorrentFile? activeFile = _activeFile;
    final String displayTitle = activeFile?.displayName ?? widget.title;
    final List<SeasonFileGroup> parsedSeasons = parseSeasonPack(_files);
    final List<SeasonFileGroup> seasonGroups = parsedSeasons
        .where((SeasonFileGroup group) => group.season > 0)
        .toList(growable: false);
    final List<ParsedEpisodeFile> extras = parsedSeasons
        .where((SeasonFileGroup group) => group.isExtras)
        .expand((SeasonFileGroup group) => group.episodes)
        .toList(growable: false);
    final bool hasStreamUrl = (_resolvedUrl ?? '').isNotEmpty;
    final bool canControl = _initialized && controller != null;
    final bool movieLikeFiles =
        widget.mediaType == 'movie' || isMovieTorrent(_files);
    final List<int> videoFileIndices = getAllVideoFiles(_files);
    final Set<int> parsedIndices = <int>{
      for (final SeasonFileGroup group in parsedSeasons)
        for (final ParsedEpisodeFile episode in group.episodes)
          episode.originalIndex,
    };
    final List<int> unparsedVideoIndices = videoFileIndices
        .where((int index) => !parsedIndices.contains(index))
        .toList(growable: false);

    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          unawaited(_persistProgress());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Player'),
          actions: <Widget>[
            if (_files.length > 1)
              IconButton(
                onPressed: _showFileSelector,
                icon: const Icon(Icons.playlist_play_outlined),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showControls = !_showControls;
                      });
                    },
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Colors.black),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          if (_initialized && controller != null)
                            FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: controller.value.size.width,
                                height: controller.value.size.height,
                                child: VideoPlayer(controller),
                              ),
                            ),
                          if (_loading)
                            const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.text,
                              ),
                            ),
                          if (_error != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: _PlayerErrorPanel(
                                  issue: _playbackIssue ??
                                      _PlaybackIssue(
                                        title: 'Playback failed',
                                        body: _error!,
                                        showExternalActions: true,
                                      ),
                                  hasFiles: _files.length > 1,
                                  hasStreamUrl: hasStreamUrl,
                                  onChooseFile: _showFileSelector,
                                  onOpenExternal: _openExternalPlayer,
                                  onCopyLink: _copyStreamUrl,
                                  onRetry: _retryActiveFile,
                                ),
                              ),
                            ),
                          if (_showControls &&
                              _initialized &&
                              controller != null)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.18),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        _OverlayControlButton(
                                          icon: Icons.replay_10,
                                          onTap: () => _seekRelative(-10),
                                        ),
                                        const SizedBox(width: 18),
                                        _OverlayControlButton(
                                          icon: isPlaying
                                              ? Icons.pause_circle_filled
                                              : Icons.play_circle_fill,
                                          size: 68,
                                          onTap: _togglePlayPause,
                                        ),
                                        const SizedBox(width: 18),
                                        _OverlayControlButton(
                                          icon: Icons.forward_10,
                                          onTap: () => _seekRelative(10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _InfoChip(
                          icon: isPlaying
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          label: isPlaying ? 'Playing' : 'Paused',
                        ),
                        if (isBuffering)
                          const _InfoChip(
                            icon: Icons.sync,
                            label: 'Buffering',
                          ),
                        if (widget.provider != null)
                          _InfoChip(
                            icon: Icons.storage_outlined,
                            label: widget.provider!,
                          ),
                        if (activeFile != null)
                          _InfoChip(
                            icon: _looksLikeHevc(activeFile.displayName)
                                ? Icons.warning_amber_rounded
                                : Icons.folder_open_outlined,
                            label: _looksLikeHevc(activeFile.displayName)
                                ? 'HEVC/x265'
                                : activeFile.displayName,
                          ),
                        if (widget.torrentHash != null &&
                            widget.torrentHash!.isNotEmpty)
                          _InfoChip(
                            icon: Icons.tag_outlined,
                            label: widget.torrentHash!.substring(
                              0,
                              widget.torrentHash!.length > 10
                                  ? 10
                                  : widget.torrentHash!.length,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      canControl
                          ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                          : 'Waiting for a playable stream',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      value: progress,
                      onChanged: !canControl
                          ? null
                          : (double value) async {
                              final int millis =
                                  (_duration.inMilliseconds * value).round();
                              await controller.seekTo(
                                Duration(milliseconds: millis),
                              );
                            },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        FilledButton.tonal(
                          onPressed: canControl ? _togglePlayPause : null,
                          child: Text(isPlaying ? 'Pause' : 'Play'),
                        ),
                        FilledButton.tonal(
                          onPressed:
                              canControl ? () => _seekRelative(-10) : null,
                          child: const Text('-10s'),
                        ),
                        FilledButton.tonal(
                          onPressed:
                              canControl ? () => _seekRelative(10) : null,
                          child: const Text('+10s'),
                        ),
                        if (hasStreamUrl)
                          FilledButton.tonal(
                            onPressed: _openExternalPlayer,
                            child: const Text('External player'),
                          ),
                        FilledButton.tonal(
                          onPressed: _saving
                              ? null
                              : () async {
                                  final ScaffoldMessengerState messenger =
                                      ScaffoldMessenger.of(context);
                                  await _persistProgress();
                                  if (!mounted) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Progress saved to Continue Watching.',
                                      ),
                                    ),
                                  );
                                },
                          child: Text(_saving ? 'Saving...' : 'Save progress'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_files.isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                if (!movieLikeFiles && seasonGroups.isNotEmpty) ...<Widget>[
                  const Text(
                    'Episodes',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Season packs are grouped by parsed episode numbers so you can jump into the right file.',
                    style: TextStyle(color: AppColors.textMuted, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  ...seasonGroups.map(
                    (SeasonFileGroup group) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _EpisodeGroupCard(
                        title: 'Season ${group.season}',
                        episodes: group.episodes,
                        files: _files,
                        activeFileId: _activeFileId,
                        onSelectFile: _loading
                            ? null
                            : (ParsedEpisodeFile episode) => _resolveFile(
                                  _files[episode.originalIndex].id,
                                ),
                      ),
                    ),
                  ),
                ],
                if (movieLikeFiles ||
                    unparsedVideoIndices.isNotEmpty) ...<Widget>[
                  Text(
                    movieLikeFiles ? 'Video files' : 'Other video files',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...unparsedVideoIndices.map(
                    (int index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FileTile(
                        file: _files[index],
                        active: _files[index].id == _activeFileId,
                        onTap: _loading
                            ? null
                            : () => _resolveFile(_files[index].id),
                        subtitle: _formatBytes(_files[index].size),
                      ),
                    ),
                  ),
                ],
                if (extras.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  Text(
                    movieLikeFiles ? 'Other files' : 'Extras',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...extras.map(
                    (ParsedEpisodeFile episode) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FileTile(
                        file: _files[episode.originalIndex],
                        active:
                            _files[episode.originalIndex].id == _activeFileId,
                        onTap: _loading
                            ? null
                            : () =>
                                _resolveFile(_files[episode.originalIndex].id),
                        leadingLabel: '#${episode.episode}',
                        subtitle:
                            '${episode.title} - ${_formatBytes(_files[episode.originalIndex].size)}',
                      ),
                    ),
                  ),
                ],
                if (!movieLikeFiles &&
                    seasonGroups.isEmpty &&
                    extras.isEmpty &&
                    _files.isNotEmpty) ...<Widget>[
                  const Text(
                    'Files',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._files.map(
                    (TorBoxTorrentFile file) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FileTile(
                        file: file,
                        active: file.id == _activeFileId,
                        onTap: _loading ? null : () => _resolveFile(file.id),
                        subtitle: _formatBytes(file.size),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration <= Duration.zero) {
      return '00:00';
    }

    final int totalSeconds = duration.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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

class _EpisodeGroupCard extends StatelessWidget {
  const _EpisodeGroupCard({
    required this.title,
    required this.episodes,
    required this.files,
    required this.activeFileId,
    required this.onSelectFile,
  });

  final String title;
  final List<ParsedEpisodeFile> episodes;
  final List<TorBoxTorrentFile> files;
  final int? activeFileId;
  final ValueChanged<ParsedEpisodeFile>? onSelectFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...episodes.map(
            (ParsedEpisodeFile episode) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FileTile(
                file: files[episode.originalIndex],
                active: files[episode.originalIndex].id == activeFileId,
                onTap:
                    onSelectFile == null ? null : () => onSelectFile!(episode),
                leadingLabel:
                    formatEpisodeLabel(episode.season, episode.episode),
                subtitle:
                    '${episode.title} - ${_formatBytesStatic(files[episode.originalIndex].size)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.active,
    required this.onTap,
    required this.subtitle,
    this.leadingLabel,
  });

  final TorBoxTorrentFile file;
  final bool active;
  final VoidCallback? onTap;
  final String subtitle;
  final String? leadingLabel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      tileColor:
          active ? Colors.white.withOpacity(0.10) : AppColors.cardBackground,
      leading: leadingLabel == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                leadingLabel!,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      title: Text(
        file.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.text),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textMuted),
      ),
      trailing: IconButton(
        onPressed: onTap,
        icon: const Icon(
          Icons.play_arrow_rounded,
          color: AppColors.text,
        ),
      ),
      onTap: onTap,
    );
  }
}

String _formatBytesStatic(int bytes) {
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: AppColors.textMuted, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackIssue {
  const _PlaybackIssue({
    required this.title,
    required this.body,
    required this.showExternalActions,
    this.rawDetails,
  });

  final String title;
  final String body;
  final bool showExternalActions;
  final String? rawDetails;

  String? get shortDetails {
    final String details = rawDetails?.trim() ?? '';
    if (details.isEmpty) {
      return null;
    }
    return details.length > 180 ? '${details.substring(0, 180)}...' : details;
  }
}

class _PlayerErrorPanel extends StatelessWidget {
  const _PlayerErrorPanel({
    required this.issue,
    required this.hasFiles,
    required this.hasStreamUrl,
    required this.onChooseFile,
    required this.onOpenExternal,
    required this.onCopyLink,
    required this.onRetry,
  });

  final _PlaybackIssue issue;
  final bool hasFiles;
  final bool hasStreamUrl;
  final VoidCallback onChooseFile;
  final Future<void> Function() onOpenExternal;
  final Future<void> Function() onCopyLink;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF180F10).withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x55F87171)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFCA5A5),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              issue.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              issue.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (hasFiles)
                  FilledButton.tonalIcon(
                    onPressed: onChooseFile,
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    label: const Text('Choose file'),
                  ),
                if (hasStreamUrl && issue.showExternalActions)
                  FilledButton.tonalIcon(
                    onPressed: onOpenExternal,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open external'),
                  ),
                if (hasStreamUrl && issue.showExternalActions)
                  OutlinedButton.icon(
                    onPressed: onCopyLink,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Copy URL'),
                  ),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
            if (issue.shortDetails != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                issue.shortDetails!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverlayControlButton extends StatelessWidget {
  const _OverlayControlButton({
    required this.icon,
    required this.onTap,
    this.size = 46,
  });

  final IconData icon;
  final Future<void> Function() onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.42),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.58),
        ),
      ),
    );
  }
}
