import 'package:flutter/material.dart';
import '../models/settings_service.dart';

class DataSavingImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  const DataSavingImage({super.key, required this.url, this.fit = BoxFit.contain, this.width, this.height});

  @override
  State<DataSavingImage> createState() => _DataSavingImageState();
}

class _DataSavingImageState extends State<DataSavingImage> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final saving = SettingsService.instance.getValue<bool>('dataSavingMode', false);
    if (saving && !_requested) {
      return SizedBox(
        width: widget.width,
        height: widget.height ?? 120,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: () => setState(() => _requested = true),
            child: const Center(child: Icon(Icons.download_for_offline_outlined)),
          ),
        ),
      );
    }
    return Image.network(widget.url, fit: widget.fit, width: widget.width, height: widget.height);
  }
}
