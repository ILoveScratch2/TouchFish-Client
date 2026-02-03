import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoViewer extends StatefulWidget {
  final String videoPath;
  final Uint8List? videoBytes;
  final double aspectRatio;
  final bool autoplay;

  const VideoViewer({
    super.key,
    required this.videoPath,
    this.videoBytes,
    this.aspectRatio = 16 / 9,
    this.autoplay = false,
  });

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  Player? _player;
  VideoController? _videoController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() async {
    MediaKit.ensureInitialized();

    _player = Player();
    _videoController = VideoController(_player!);

    String mediaSource;
    if (kIsWeb && widget.videoBytes != null) {
      final base64String = base64Encode(widget.videoBytes!);
      mediaSource = 'data:video/mp4;base64,$base64String';
    } else {
      mediaSource = widget.videoPath;
    }

    _player!.open(
      Media(mediaSource),
      play: widget.autoplay,
    );

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Video(
      controller: _videoController!,
      aspectRatio: widget.aspectRatio != 1 ? widget.aspectRatio : null,
      fit: BoxFit.contain,
      controls:
          !kIsWeb && (Platform.isAndroid || Platform.isIOS)
              ? MaterialVideoControls
              : MaterialDesktopVideoControls,
    );
  }
}
