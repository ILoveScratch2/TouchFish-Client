import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/media_proxy_service.dart';
import '../../services/playback_coordinator.dart';
import '../../services/snackbar_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/clipboard_utils.dart';
import '../../utils/talker.dart';

class VideoViewer extends StatefulWidget {
  final String videoPath;
  final Uint8List? videoBytes;
  final double aspectRatio;
  final bool autoplay;

  /// 首次真正开始播放
  final VoidCallback? onPlaybackStarted;

  /// 未播放时展示的封面
  final String? posterUrl;

  const VideoViewer({
    super.key,
    required this.videoPath,
    this.videoBytes,
    this.aspectRatio = 16 / 9,
    this.autoplay = false,
    this.onPlaybackStarted,
    this.posterUrl,
  });

  @override
  State<VideoViewer> createState() => VideoViewerState();
}

class VideoViewerState extends State<VideoViewer> with RouteAware {
  Player? _player;
  VideoController? _videoController;
  String? _errorMessage;
  bool _hasError = false;
  bool _isPlaying = false;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<String>? _errorSubscription;
  Timer? _errorGraceTimer;

  bool get isPlaying => _isPlaying;

  /// 播放器是否已真正创建
  bool _initializing = false;

  Route<dynamic>? _subscribedRoute;

  /// 已通知过调用方
  bool _notifiedPlaybackStart = false;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    if (widget.autoplay) {
      unawaited(_ensurePlayer(playAfterInit: true));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _subscribedRoute) return;
    if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
    _subscribedRoute = route;
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  /// 页面被新路由覆盖
  @override
  void didPushNext() {
    final player = _player;
    if (_isPlaying && player != null) unawaited(player.pause());
  }

  @override
  void didPopNext() {}

  /// 创建播放
  Future<void> _ensurePlayer({bool playAfterInit = false}) async {
    if (_player != null || _initializing) {
      if (playAfterInit && _player != null) await _player!.play();
      return;
    }
    _initializing = true;
    try {
      await _initPlayer();
    } finally {
      _initializing = false;
    }
    if (!mounted || _player == null) return;
    if (playAfterInit) await _player!.play();
    setState(() {});
  }

  void _onPlayerError(String error) {
    talker.error('Video player error: $error');
    final player = _player;
    if (player == null) return;
    if (player.state.duration == Duration.zero && !player.state.playing) {
      _showError(error);
      return;
    }
    _errorGraceTimer?.cancel();
    _errorGraceTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final current = _player;
      if (current == null) return;
      if (current.state.duration == Duration.zero || current.state.width == 0) {
        _showError(error);
      }
    });
  }

  void _showError(String error) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _errorMessage = error;
    });
  }

  @override
  void dispose() {
    PlaybackCoordinator.instance.release(this);
    _errorGraceTimer?.cancel();
    _errorGraceTimer = null;
    if (_subscribedRoute != null) {
      appRouteObserver.unsubscribe(this);
      _subscribedRoute = null;
    }
    _disposePlayer();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath ||
        oldWidget.videoBytes != widget.videoBytes) {
      _hasError = false;
      _errorMessage = null;
      _disposePlayer();
      if (widget.autoplay) {
        unawaited(_ensurePlayer(playAfterInit: true));
      }
    }
  }

  Future<void> _initPlayer() async {
    MediaKit.ensureInitialized();
    _player = Player();
    _videoController = VideoController(_player!);

    _playingSubscription = _player!.stream.playing.listen((playing) {
      if (playing) {
        final player = _player;
        if (player != null) {
          // 同一时刻只允许一个播放器
          PlaybackCoordinator.instance.claim(this, player.pause);
        }
        if (!_notifiedPlaybackStart) {
          _notifiedPlaybackStart = true;
          widget.onPlaybackStarted?.call();
        }
      }
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          _hasError = false;
          _errorMessage = null;
        });
      }
    });

    _errorSubscription = _player!.stream.error.listen(_onPlayerError);

    String mediaSource;
    if (kIsWeb && widget.videoBytes != null) {
      final base64String = base64Encode(widget.videoBytes!);
      mediaSource = 'data:video/mp4;base64,$base64String';
    } else {
      mediaSource = await MediaProxyService.instance.resolveUrl(
        widget.videoPath,
      );
    }

    if (!mounted || _player == null) return;
    _player!.open(Media(mediaSource), play: widget.autoplay);
  }

  void _disposePlayer() {
    _errorGraceTimer?.cancel();
    _errorGraceTimer = null;
    _playingSubscription?.cancel();
    _playingSubscription = null;
    _errorSubscription?.cancel();
    _errorSubscription = null;
    _player?.dispose();
    _player = null;
    _videoController = null;
  }

  void _handleRetry() {
    if (_player == null) {
      unawaited(_ensurePlayer(playAfterInit: true));
      setState(() => _hasError = false);
      return;
    }
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });
    _disposePlayer();
    _initPlayer();
  }

  Future<void> play() async {
    await _player?.play();
  }

  Future<void> pause() async {
    await _player?.pause();
  }

  Future<void> playPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final content = _buildContent(context);
        if (boundedHeight) return content;
        return AspectRatio(aspectRatio: widget.aspectRatio, child: content);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_hasError) {
      return _VideoErrorWidget(
        errorMessage:
            _errorMessage ?? AppLocalizations.of(context)!.commonUnknown,
        onRetry: _handleRetry,
      );
    }

    if (_videoController == null) {
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.posterUrl != null)
              Image.network(
                widget.posterUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if (widget.posterUrl != null)
              const DecoratedBox(
                decoration: BoxDecoration(color: Colors.black38),
              ),
            Center(
              child: _initializing
                  ? const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : IconButton.filled(
                      iconSize: 40,
                      onPressed: () => _ensurePlayer(playAfterInit: true),
                      icon: const Icon(Icons.play_arrow),
                      tooltip: AppLocalizations.of(context)!.videoTapToPlay,
                    ),
            ),
          ],
        ),
      );
    }

    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    Widget video = Video(
      controller: _videoController!,
      aspectRatio: null,
      fit: BoxFit.contain,
      controls: isMobile ? MaterialVideoControls : MaterialDesktopVideoControls,
      fill: Colors.black,
      filterQuality: FilterQuality.high,
    );

    if (isMobile) {
      video = MaterialVideoControlsTheme(
        normal: MaterialVideoControlsThemeData(
          visibleOnMount: true,
          // 控制条 3 秒后自动隐藏
          controlsHoverDuration: const Duration(seconds: 3),
          volumeGesture: true,
          brightnessGesture: true,
          seekGesture: true,
          seekOnDoubleTap: true,
          seekBarPositionColor: primaryColor,
          seekBarColor: primaryColor.withValues(alpha: 0.3),
          seekBarBufferColor: primaryColor.withValues(alpha: 0.5),
          seekBarThumbColor: primaryColor,
          bottomButtonBar: const [
            MaterialPositionIndicator(),
            Spacer(),
            MaterialFullscreenButton(),
          ],
        ),
        fullscreen: MaterialVideoControlsThemeData(
          visibleOnMount: true,
          // 控制条 3 秒后自动隐
          controlsHoverDuration: const Duration(seconds: 3),
          volumeGesture: true,
          brightnessGesture: true,
          seekGesture: true,
          seekOnDoubleTap: true,
          seekBarPositionColor: primaryColor,
          seekBarColor: primaryColor.withValues(alpha: 0.3),
          seekBarBufferColor: primaryColor.withValues(alpha: 0.5),
          seekBarThumbColor: primaryColor,
          bottomButtonBar: const [
            MaterialPositionIndicator(),
            Spacer(),
            MaterialFullscreenButton(),
          ],
        ),
        child: video,
      );
    } else {
      video = MaterialDesktopVideoControlsTheme(
        normal: MaterialDesktopVideoControlsThemeData(
          visibleOnMount: true,
          controlsHoverDuration: const Duration(seconds: 3),
          seekBarPositionColor: primaryColor,
          seekBarColor: primaryColor.withValues(alpha: 0.3),
          seekBarBufferColor: primaryColor.withValues(alpha: 0.5),
          seekBarThumbColor: primaryColor,
          bottomButtonBar: const [
            MaterialDesktopPlayOrPauseButton(),
            MaterialDesktopVolumeButton(),
            MaterialDesktopPositionIndicator(),
            Spacer(),
            MaterialDesktopFullscreenButton(),
          ],
        ),
        fullscreen: MaterialDesktopVideoControlsThemeData(
          visibleOnMount: true,
          controlsHoverDuration: const Duration(seconds: 3),
          seekBarPositionColor: primaryColor,
          seekBarColor: primaryColor.withValues(alpha: 0.3),
          seekBarBufferColor: primaryColor.withValues(alpha: 0.5),
          seekBarThumbColor: primaryColor,
          bottomButtonBar: const [
            MaterialDesktopPlayOrPauseButton(),
            MaterialDesktopVolumeButton(),
            MaterialDesktopPositionIndicator(),
            Spacer(),
            MaterialDesktopFullscreenButton(),
          ],
        ),
        child: video,
      );
    }

    return video;
  }
}

class _VideoErrorWidget extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const _VideoErrorWidget({
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxHeight.isFinite &&
              (constraints.maxHeight < 220 || constraints.maxWidth < 300);
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(tight ? 8 : 16),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tight ? 10 : 20,
                  vertical: tight ? 10 : 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(tight ? 10 : 16),
                  border: Border.all(color: colorScheme.error, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.error,
                      size: tight ? 24 : 44,
                      color: colorScheme.error,
                    ),
                    SizedBox(height: tight ? 4 : 12),
                    Text(
                      l10n.videoPlaybackErrorTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.error,
                        fontSize: tight ? 13 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: tight ? 4 : 10),
                    if (tight)
                      Text(
                        errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.videoPlaybackErrorDetails,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              errorMessage,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: tight ? 6 : 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: tight
                          ? [
                              IconButton(
                                onPressed: onRetry,
                                iconSize: 20,
                                visualDensity: VisualDensity.compact,
                                tooltip: l10n.retry,
                                icon: Icon(
                                  Symbols.refresh,
                                  color: colorScheme.error,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _copyError(context),
                                iconSize: 18,
                                visualDensity: VisualDensity.compact,
                                tooltip: l10n.messageActionCopy,
                                icon: const Icon(
                                  Symbols.content_copy,
                                  color: Colors.white70,
                                ),
                              ),
                            ]
                          : [
                              ElevatedButton.icon(
                                onPressed: onRetry,
                                icon: const Icon(Symbols.refresh, size: 18),
                                label: Text(l10n.retry),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.error,
                                  foregroundColor: colorScheme.onError,
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => _copyError(context),
                                icon: const Icon(Symbols.content_copy, size: 18),
                                label: Text(l10n.messageActionCopy),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white30),
                                ),
                              ),
                            ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _copyError(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final copied = await copyTextToClipboard(errorMessage);
    TouchFishSnackbarService.instance.show(
      copied ? l10n.aboutCopiedToClipboard : l10n.copyFailedText,
      type: copied ? SnackbarType.info : SnackbarType.error,
    );
  }
}
