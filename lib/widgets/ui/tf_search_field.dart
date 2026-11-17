import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 统一搜索输入框
class TFSearchField extends StatefulWidget {
  const TFSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.debounce = const Duration(milliseconds: 300),
    this.autofocus = false,
    this.focusNode,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hintText;

  /// 防抖后触发
  /// `debounce: Duration.zero` 时立即触发。
  final ValueChanged<String>? onChanged;

  /// 键盘搜索键触发
  final ValueChanged<String>? onSubmitted;

  final VoidCallback? onClear;

  final Duration debounce;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool enabled;

  @override
  State<TFSearchField> createState() => _TFSearchFieldState();
}

class _TFSearchFieldState extends State<TFSearchField> {
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant TFSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _handleChanged(String value) {
    _debounceTimer?.cancel();
    final debounce = widget.debounce;
    if (debounce <= Duration.zero) {
      widget.onChanged?.call(value);
      return;
    }
    _debounceTimer = Timer(debounce, () => widget.onChanged?.call(value));
  }

  void _handleClear() {
    _debounceTimer?.cancel();
    widget.controller.clear();
    final onClear = widget.onClear;
    if (onClear != null) {
      onClear();
    } else {
      widget.onChanged?.call('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = widget.controller.text.isNotEmpty;
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      textInputAction: TextInputAction.search,
      onChanged: _handleChanged,
      onSubmitted: (value) {
        _debounceTimer?.cancel();
        widget.onSubmitted?.call(value);
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: hasText
            ? IconButton(
                tooltip: MaterialLocalizations.of(
                  context,
                ).deleteButtonTooltip,
                icon: const Icon(Icons.close),
                onPressed: _handleClear,
              )
            : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TFSpace.md,
          vertical: TFSpace.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TFRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TFRadius.sm),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TFRadius.sm),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
    );
  }
}
