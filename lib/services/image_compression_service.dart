import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import '../models/settings_service.dart';
import '../utils/file_type_detector.dart';

/// 上传前压缩图片
/// 判定为不适合压缩时返回 null
class ImageCompressionService {
  ImageCompressionService._();
  static final ImageCompressionService instance = ImageCompressionService._();

  Future<PreparedImageUpload?> prepareForUpload({
    required List<int> bytes,
    required String fileName,
    bool? enabled,
    int? quality,
  }) async {
    final settings = SettingsService.instance;
    final usable =
        enabled ??
        settings.getValue<bool>('imageCompressionEnabled', true);
    if (!usable) return null;

    final source = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    // 太小的图重编码收益不抵一次有损转换，太大的图解码会吃掉大量内存。
    if (source.length < _kMinSourceBytes || source.length > _kMaxSourceBytes) {
      return null;
    }

    final configured =
        quality ??
        (settings.getValue<double>('imageCompressionQuality', 0.8) * 100)
            .round();
    final effectiveQuality = configured.clamp(_kMinQuality, _kMaxQuality);

    final info = _probe(source);
    if (info == null) {
      // HEIC/HEIF 只有 Android/iOS 的系统编解码器能读（image 包不支持），
      // 探测不到尺寸，只能让原生侧自己缩。
      if (_nativeSupported && _looksLikeHeif(source)) {
        return _finish(
          await _compressWithPlatformCodec(source, null, effectiveQuality),
          source,
          fileName,
        );
      }
      return null;
    }
    // 动图（GIF / APNG / 动图 WebP）压成单帧就 BOOM，原样上传。
    if (info.numFrames > 1) return null;
    if (info.width * info.height > _kMaxSourcePixels) return null;

    // 原生编解码器只在 Android/iOS 可用（Windows/Linux 该插件没有实现）。
    final native = _nativeSupported
        ? await _compressWithPlatformCodec(
            source,
            info,
            effectiveQuality,
          )
        : null;
    // 原生失败（或不可用）时退回纯 Dart；两条路都不碰 isolate 里的插件调用。
    final compressed =
        native ??
        await compute(_compressInDart, <Object?>[source, effectiveQuality]);

    return _finish(compressed, source, fileName);
  }

  bool get _nativeSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 绝不让"压缩"把文件变大。
  PreparedImageUpload? _finish(
    Uint8List? compressed,
    Uint8List source,
    String fileName,
  ) {
    if (compressed == null ||
        compressed.isEmpty ||
        compressed.length >= source.length) {
      return null;
    }
    // 扩展名跟着实际内容走，服务端按扩展名判定文件类型。
    return PreparedImageUpload(
      bytes: compressed,
      fileName: ensureFileExtension(fileName, compressed),
    );
  }

  /// 只用头部信息探测（`startDecode` 不解码像素），失败视作不可压缩。
  _ImageProbe? _probe(Uint8List source) {
    try {
      final info = img.findDecoderForData(source)?.startDecode(source);
      if (info == null || info.width <= 0 || info.height <= 0) return null;
      return _ImageProbe(
        width: info.width,
        height: info.height,
        numFrames: info.numFrames,
      );
    } catch (_) {
      // 部分解码器（如 WebP）遇到畸形输入会直接抛异常。
      return null;
    }
  }

  Future<Uint8List?> _compressWithPlatformCodec(
    Uint8List source,
    _ImageProbe? info,
    int quality,
  ) async {
    var minWidth = _kMaxEdge;
    var minHeight = _kMaxEdge;
    if (info != null) {
      // 插件的 minWidth/minHeight 限制的是**短边**（见 Android calcScale 与
      // iOS scaleWithMinWidth），照抄 1920/1920 会留下 2560 宽的长边；
      // 按探测尺寸反推，才能让最长边正好落在 1920。
      final scale =
          _kMaxEdge / (info.width > info.height ? info.width : info.height);
      minWidth = (info.width * scale).round().clamp(1, _kMaxEdge);
      minHeight = (info.height * scale).round().clamp(1, _kMaxEdge);
    }

    try {
      final result = await FlutterImageCompress.compressWithList(
        source,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
        format: CompressFormat.webp,
      );
      return result.isEmpty ? null : result;
    } catch (_) {
      // 无实现的平台会**同步**抛错，真机编码失败同理，交给纯 Dart 回退。
      return null;
    }
  }
}

/// 压缩结果：上传时改用这里的字节与文件名。
class PreparedImageUpload {
  final Uint8List bytes;
  final String fileName;

  const PreparedImageUpload({required this.bytes, required this.fileName});
}

class _ImageProbe {
  final int width;
  final int height;
  final int numFrames;

  const _ImageProbe({
    required this.width,
    required this.height,
    required this.numFrames,
  });
}

const int _kMinSourceBytes = 100 * 1024;
const int _kMaxSourceBytes = 32 * 1024 * 1024;
const int _kMaxEdge = 1920;
const int _kMinQuality = 10;
const int _kMaxQuality = 100;

/// 服务端对超过该像素数的图直接放弃生成缩略图，客户端也没必要解码它。
const int _kMaxSourcePixels = 40 * 1000 * 1000;

/// `[Uint8List source, int quality]` -> 缩小的 JPEG 字节，失败返回 null。
///
/// 顶层函数，供 `compute` 在 isolate 中执行：这里**不能**碰 `Platform`，
/// 也不能调用插件（平台通道只能在主 isolate 上用）。
Uint8List? _compressInDart(List<Object?> args) {
  try {
    final source = args[0] as Uint8List;
    final quality = args[1] as int;
    final decoded = img.decodeImage(source);
    if (decoded == null || decoded.hasAnimation) return null;

    var image = decoded;
    // 重编码写不出原始 EXIF 方向，必须先把方向烘进像素，否则竖拍照片会躺倒。
    final orientation = image.exif.imageIfd.orientation;
    if (image.exif.imageIfd.hasOrientation && orientation != 1) {
      image = img.bakeOrientation(image);
    }

    final longest = image.width > image.height ? image.width : image.height;
    if (longest > _kMaxEdge) {
      // copyResize 只给一条边即可按比例缩放；average 明显优于默认的 nearest。
      image = image.width >= image.height
          ? img.copyResize(
              image,
              width: _kMaxEdge,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              image,
              height: _kMaxEdge,
              interpolation: img.Interpolation.average,
            );
    }

    // 真透明像素转成 JPEG 会被填成白底（image 包的行为），宁可不压。
    // 调色板图（如 GIF / 索引 PNG）的透明度在调色板里，hasAlpha 看不出来，
    // 所以连同 hasPalette 一起扫；放在缩放之后扫，最多 1920x1920 个像素。
    if (image.hasAlpha || image.hasPalette) {
      for (final pixel in image) {
        if (pixel.a < 255) return null;
      }
    }

    return img.encodeJpg(image, quality: quality);
  } catch (_) {
    return null;
  }
}

const Set<String> _kHeifBrands = {
  'heic',
  'heix',
  'hevc',
  'hevx',
  'heim',
  'heis',
  'hevm',
  'hevs',
  'mif1',
  'msf1',
};

/// ISO-BMFF 的 `ftyp` box + HEIF 品牌，用来在探测失败时认出 HEIC 照片。
bool _looksLikeHeif(Uint8List source) {
  if (source.length < 12) return false;
  if (source[4] != 0x66 || // f
      source[5] != 0x74 || // t
      source[6] != 0x79 || // y
      source[7] != 0x70) {
    return false;
  }
  try {
    return _kHeifBrands.contains(
      String.fromCharCodes(source.sublist(8, 12)),
    );
  } catch (_) {
    return false;
  }
}
