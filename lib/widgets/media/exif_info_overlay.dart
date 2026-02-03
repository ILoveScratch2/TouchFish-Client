import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ExifInfoOverlay extends StatelessWidget {
  final Map<String, dynamic>? exifData;

  const ExifInfoOverlay({super.key, this.exifData});

  bool _isPreferredValue(String key, String value) {
    if ([
      'ExposureTime',
      'FNumber',
      'FocalLength',
      'ApertureValue',
      'DateTime',
    ].contains(key)) {
      return true;
    }
    return false;
  }

  String _formatExifValue(String key, String value) {
    final lastOpen = value.lastIndexOf('(');
    final lastClose = value.endsWith(')') ? value.length - 1 : -1;

    if (lastOpen == -1 || lastClose == -1 || lastOpen > lastClose) {
      return value;
    }

    final inside = value.substring(lastOpen + 1, lastClose);
    final commaIndex = inside.indexOf(',');

    if (commaIndex != -1) {
      final candidate = inside.substring(0, commaIndex).trim();

      if (_isPreferredValue(key, candidate)) {
        return candidate;
      }
    }

    if (lastOpen == -1) {
      return value;
    }

    return value.substring(0, lastOpen).trimRight();
  }

  @override
  Widget build(BuildContext context) {
    if (exifData == null || exifData!.isEmpty) {
      return const SizedBox.shrink();
    }

    final dateTime = exifData!['DateTime'];
    final model = exifData!['Model'];
    final iso = exifData!['ISOSpeedRatings'];
    final fnumber = exifData!['FNumber'];
    final exposureTime = exifData!['ExposureTime'];
    final focalLength = exifData!['FocalLength'];

    final items = <Widget>[];

    if (dateTime != null && dateTime.toString().isNotEmpty) {
      items.add(_buildExifItem('DateTime', dateTime.toString(), Symbols.calendar_check));
    }
    if (model != null && model.toString().isNotEmpty) {
      items.add(_buildExifItem('Model', model.toString(), Symbols.camera_alt));
    }
    if (iso != null) {
      items.add(_buildExifItem('ISO', iso.toString(), Icons.iso));
    }
    if (fnumber != null) {
      items.add(_buildExifItem('FNumber', fnumber.toString(), Symbols.camera_enhance));
    }
    if (exposureTime != null) {
      items.add(
        _buildExifItem('ExposureTime', exposureTime.toString(), Icons.shutter_speed),
      );
    }
    if (focalLength != null) {
      items.add(
        _buildExifItem(
          'FocalLength',
          focalLength.toString(),
          Symbols.photo_size_select_large,
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Wrap(
          alignment: WrapAlignment.end,
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: item,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildExifItem(String key, String value, IconData icon) {
    final formattedValue = _formatExifValue(key, value);
    final shadow = [
      Shadow(
        color: Colors.black54,
        blurRadius: 5.0,
        offset: const Offset(1.0, 1.0),
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70, shadows: shadow),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            formattedValue,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: shadow,
            ),
          ),
        ),
      ],
    );
  }
}
