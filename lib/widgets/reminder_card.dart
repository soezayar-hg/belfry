import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/bangkok_time.dart';
import '../theme/belfry_theme.dart';
import 'belfry_button.dart';

/// A single reminder in the list — the prototype's `.card`. [occurrence] is
/// the resolved next fire time (computed by the caller from the anchor +
/// recurrence rule).
class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.occurrence,
    required this.now,
    required this.onEdit,
    required this.onDelete,
  });

  final Reminder reminder;
  final DateTime occurrence;
  final DateTime now;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final diff = occurrence.difference(now);
    final countdownColor = diff.isNegative
        ? BelfryColors.danger
        : diff.inHours < 1
        ? BelfryColors.accentInk
        : BelfryColors.ink3;

    return Container(
      decoration: BoxDecoration(
        color: BelfryColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BelfryColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      children: [
                        Text(
                          reminder.title,
                          style: BelfryText.sans(
                            size: 16,
                            weight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          BangkokTime.formatRelative(occurrence, now),
                          style: BelfryText.sans(
                            size: 12,
                            weight: diff.inHours < 1 && !diff.isNegative
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: countdownColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      BangkokTime.formatFull(occurrence),
                      style: BelfryText.mono(size: 13, color: BelfryColors.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BelfryIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
              BelfryIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                onPressed: onDelete,
                hoverColor: BelfryColors.danger,
              ),
            ],
          ),
          if (reminder.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reminder.note,
              style: BelfryText.sans(size: 13, color: BelfryColors.ink3),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (reminder.recurrence.repeats)
                _Tag(
                  label: reminder.recurrence.label.toLowerCase(),
                  icon: Icons.repeat,
                  accent: true,
                ),
              for (final lead in reminder.leadTimes)
                _Tag(label: '−${lead.shortLabel}'),
              const _Tag(label: '⏰ at exact'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon, this.accent = false});

  final String label;
  final IconData? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final fg = accent ? BelfryColors.accentInk : BelfryColors.ink2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? BelfryColors.accentSoft : BelfryColors.tagBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: BelfryText.sans(size: 11, color: fg, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
