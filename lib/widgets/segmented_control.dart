import 'package:flutter/material.dart';

import '../theme/belfry_theme.dart';

class SegmentOption<T> {
  const SegmentOption(this.value, this.label);
  final T value;
  final String label;
}

/// The prototype's `.seg` — a row of equal-width buttons, the selected one
/// filled with the primary colour.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BelfryColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BelfryColors.line2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: _Segment(
                label: options[i].label,
                selected: options[i].value == value,
                showDivider: i != options.length - 1,
                onTap: () => onChanged(options[i].value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? BelfryColors.primary : Colors.transparent,
        border: showDivider
            ? const Border(
                right: BorderSide(color: BelfryColors.line),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: BelfryText.sans(
                size: 13,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? BelfryColors.onPrimary : BelfryColors.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
