import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/tokens.dart';

/// 三态：不限 / 是 / 否。
enum TriStateFilter { any, yes, no }

class TriStateFilterChip extends StatelessWidget {
  final String label;
  final TriStateFilter value;
  final ValueChanged<TriStateFilter> onChanged;

  const TriStateFilterChip({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// 点击循环
  void _cycle() {
    onChanged(
      switch (value) {
        TriStateFilter.any => TriStateFilter.yes,
        TriStateFilter.yes => TriStateFilter.no,
        TriStateFilter.no => TriStateFilter.any,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = value != TriStateFilter.any;

    final (icon, activeColor) = switch (value) {
      TriStateFilter.any => (Symbols.radio_button_unchecked, null),
      TriStateFilter.yes => (Symbols.check_circle, colorScheme.primary),
      TriStateFilter.no => (Symbols.remove_circle, colorScheme.error),
    };

    return FilterChip(
      selected: active,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: TFSize.iconSm,
        color: activeColor ?? colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      onSelected: (_) => _cycle(),
    );
  }
}

/// 判断某条记录是否通过
bool passesTriState(TriStateFilter filter, bool predicate) {
  return switch (filter) {
    TriStateFilter.any => true,
    TriStateFilter.yes => predicate,
    TriStateFilter.no => !predicate,
  };
}
