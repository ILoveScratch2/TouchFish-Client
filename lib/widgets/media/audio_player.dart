import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:media_kit/media_kit.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';

class AudioPlayer extends HookWidget {
  final String audioPath;
  final Uint8List? audioBytes;
  final String? filename;
  final bool autoplay;

  const AudioPlayer({
    super.key,
    required this.audioPath,
    this.audioBytes,
    this.filename,
    this.autoplay = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = useMemoized(() {
      MediaKit.ensureInitialized();
      return Player();
    }, []);

    final duration = useState(const Duration(seconds: 1));
    final durationBuffered = useState(const Duration(seconds: 1));
    final position = useState(const Duration(seconds: 0));
    final isPlaying = useState(false);
    final sliderWorking = useState(false);
    final sliderPosition = useState(const Duration(seconds: 0));

    useEffect(() {
      player.stream.position.listen((value) {
        position.value = value;
        if (!sliderWorking.value) sliderPosition.value = position.value;
      });
      player.stream.buffer.listen((value) {
        durationBuffered.value = value;
      });
      player.stream.duration.listen((value) {
        duration.value = value;
      });
      player.stream.playing.listen((value) {
        isPlaying.value = value;
      });

      String mediaSource;
      if (kIsWeb && audioBytes != null) {
        final base64String = base64Encode(audioBytes!);
        mediaSource = 'data:audio/mpeg;base64,$base64String';
      } else {
        mediaSource = audioPath;
      }

      player.open(Media(mediaSource), play: autoplay);

      return () {
        player.dispose();
      };
    }, []);

    String formatDuration(Duration d) {
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            IconButton.filled(
              onPressed: () {
                player.playOrPause();
              },
              icon: isPlaying.value
                  ? const Icon(Symbols.pause, fill: 1, color: Colors.white)
                  : const Icon(Symbols.play_arrow, fill: 1, color: Colors.white),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: (isPlaying.value || sliderWorking.value)
                        ? SizedBox(
                            width: double.infinity,
                            key: const ValueKey('playing'),
                            child: Text(
                              '${formatDuration(position.value)} / ${formatDuration(duration.value)}',
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            key: const ValueKey('filename'),
                            child: Text(
                              filename?.isEmpty ?? true ? AppLocalizations.of(context)!.mediaAudioMessage : filename!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ),
                  Slider(
                    value: sliderPosition.value.inMilliseconds.toDouble(),
                    secondaryTrackValue:
                        durationBuffered.value.inMilliseconds.toDouble(),
                    max: duration.value.inMilliseconds.toDouble(),
                    onChangeStart: (_) {
                      sliderWorking.value = true;
                    },
                    onChanged: (value) {
                      sliderPosition.value = Duration(milliseconds: value.toInt());
                    },
                    onChangeEnd: (value) {
                      sliderPosition.value = Duration(milliseconds: value.toInt());
                      sliderWorking.value = false;
                      player.seek(sliderPosition.value);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
