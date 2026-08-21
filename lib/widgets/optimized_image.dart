import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// 计算图片解码的缓存！
({int? width, int? height}) imageDecodeSize(
  double devicePixelRatio, {
  double? width,
  double? height,
}) {
  if (kIsWeb) return (width: null, height: null);
  return (
    width:
        width != null && width > 0 ? (width * devicePixelRatio).round() : null,
    height: height != null && height > 0
        ? (height * devicePixelRatio).round()
        : null,
  );
}


ImageProvider resizedImageProvider(
  ImageProvider provider,
  double devicePixelRatio, {
  double? width,
  double? height,
}) {
  if (kIsWeb) return provider;
  final size = imageDecodeSize(devicePixelRatio, width: width, height: height);
  if (size.width == null && size.height == null) return provider;
  return ResizeImage(
    provider,
    width: size.width,
    height: size.height,
    policy: ResizeImagePolicy.fit,
  );
}

/// 按实际渲染尺寸下采样解码的图片。
class OptimizedImage extends StatelessWidget {
  final ImageProvider provider;
  final BoxFit fit;
  final bool gaplessPlayback;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageFrameBuilder? frameBuilder;

  const OptimizedImage({
    super.key,
    required this.provider,
    this.fit = BoxFit.contain,
    this.gaplessPlayback = false,
    this.errorBuilder,
    this.frameBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var imageProvider = provider;
        if (!kIsWeb) {
          final size = imageDecodeSize(
            MediaQuery.of(context).devicePixelRatio,
            width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          );
          if (size.width != null || size.height != null) {
            imageProvider = ResizeImage(
              provider,
              width: size.width,
              height: size.height,
              policy: ResizeImagePolicy.fit,
            );
          }
        }
        return Image(
          image: imageProvider,
          fit: fit,
          gaplessPlayback: gaplessPlayback,
          errorBuilder: errorBuilder,
          frameBuilder: frameBuilder,
        );
      },
    );
  }
}
