import 'package:flutter/material.dart';

import '../theme/belfry_theme.dart';

enum BelfryButtonVariant { primary, neutral, ghost }

/// The prototype's `.btn` in its primary / neutral / ghost variants.
class BelfryButton extends StatelessWidget {
  const BelfryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BelfryButtonVariant.neutral,
    this.icon,
    this.expand = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BelfryButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == BelfryButtonVariant.primary;
    final isGhost = variant == BelfryButtonVariant.ghost;

    final fg = isPrimary
        ? BelfryColors.onPrimary
        : isGhost
        ? BelfryColors.ink2
        : BelfryColors.ink;
    final bg = isPrimary
        ? BelfryColors.primary
        : isGhost
        ? Colors.transparent
        : BelfryColors.panel;
    final border = isPrimary
        ? BelfryColors.primary
        : isGhost
        ? Colors.transparent
        : BelfryColors.line2;

    final enabled = onPressed != null && !busy;

    Widget child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: BelfryText.sans(size: 14, weight: FontWeight.w500, color: fg),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small square icon-only button — the prototype's `.icon-btn`.
class BelfryIconButton extends StatelessWidget {
  const BelfryIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = BelfryColors.ink3,
    this.hoverColor = BelfryColors.ink,
    this.size = 18,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color color;
  final Color hoverColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        hoverColor: BelfryColors.navHover,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
