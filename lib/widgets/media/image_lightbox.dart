import 'dart:io';
import 'dart:math' as math;
import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:photo_view/photo_view.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'exif_info_overlay.dart';

class ImageLightbox extends HookWidget {
  final String imagePath;
  final String heroTag;
  final Map<String, dynamic>? exifData;

  const ImageLightbox({
    super.key,
    required this.imagePath,
    required this.heroTag,
    this.exifData,
  });

  @override
  Widget build(BuildContext context) {
    final photoViewController = useMemoized(() => PhotoViewController(), []);
    final rotation = useState(0);
    final showExif = useState(exifData != null && exifData!.isNotEmpty);

    final shadow = [
      Shadow(
        color: Colors.black54,
        blurRadius: 5.0,
        offset: const Offset(1.0, 1.0),
      ),
    ];

    return DismissiblePage(
      isFullScreen: true,
      backgroundColor: Colors.transparent,
      direction: DismissiblePageDismissDirection.down,
      onDismissed: () {
        Navigator.of(context).pop();
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerSignal: (pointerSignal) {
                try {
                  final delta =
                      (pointerSignal as dynamic).scrollDelta.dy as double?;
                  if (delta != null && delta != 0) {
                    final currentScale = photoViewController.scale ?? 1.0;
                    final newScale = delta > 0
                        ? currentScale * 0.9
                        : currentScale * 1.1;
                    final clampedScale = newScale.clamp(0.1, 10.0);
                    photoViewController.scale = clampedScale;
                  }
                } catch (e) {
                  // Ignore non-scroll events
                }
              },
              child: PhotoView(
                backgroundDecoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                ),
                controller: photoViewController,
                heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
                imageProvider: FileImage(File(imagePath)),
                customSize: MediaQuery.of(context).size,
                basePosition: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.close,
                color: Colors.white,
                shadows: shadow,
              ),
            ),
          ),
          // EXIF Info Overlay
          if (showExif.value && exifData != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 60,
              left: 16,
              right: 16,
              child: ExifInfoOverlay(exifData: exifData),
            ),
          // Control buttons at bottom
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: Colors.white, shadows: shadow),
                  onPressed: () {
                    photoViewController.scale =
                        (photoViewController.scale ?? 1) - 0.05;
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add, color: Colors.white, shadows: shadow),
                  onPressed: () {
                    photoViewController.scale =
                        (photoViewController.scale ?? 1) + 0.05;
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.rotate_left, color: Colors.white, shadows: shadow),
                  onPressed: () {
                    rotation.value = (rotation.value - 1) % 4;
                    photoViewController.rotation = rotation.value * -math.pi / 2;
                  },
                ),
                IconButton(
                  icon: Icon(Icons.rotate_right, color: Colors.white, shadows: shadow),
                  onPressed: () {
                    rotation.value = (rotation.value + 1) % 4;
                    photoViewController.rotation = rotation.value * -math.pi / 2;
                  },
                ),
                if (exifData != null && exifData!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      showExif.value ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                      shadows: shadow,
                    ),
                    onPressed: () {
                      showExif.value = !showExif.value;
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
