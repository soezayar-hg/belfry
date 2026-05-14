import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/bangkok_time.dart';
import '../theme/belfry_theme.dart';
import '../widgets/belfry_button.dart';

/// The full-screen ringing alarm — the prototype's `AlarmModal`. Shown when an
/// exact-time alarm fires. Snooze is a fixed 5 minutes.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({
    super.key,
    required this.reminder,
    required this.occurrence,
    required this.onSnooze,
    required this.onDismiss,
  });

  final Reminder reminder;
  final DateTime occurrence;
  final VoidCallback onSnooze;
  final VoidCallback onDismiss;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _startRinging();
  }

  /// Loops the alarm tone for as long as the ringing screen is shown. The
  /// melody alternates by the Bangkok day-of-month so consecutive days don't
  /// sound identical.
  Future<void> _startRinging() async {
    final asset = BangkokTime.now().day.isEven
        ? 'sounds/alarm_even_day.mp3'
        : 'sounds/alarm_odd_day.mp3';
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1);
      await _player.play(AssetSource(asset));
    } catch (error) {
      debugPrint('AlarmScreen: could not start alarm sound: $error');
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reminder = widget.reminder;
    return Material(
      color: BelfryColors.alarmScrim,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: BelfryColors.panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BelfryColors.line),
              ),
              padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pulsingBell(),
                  const SizedBox(height: 20),
                  Text(
                    'REMINDER · NOW',
                    style: BelfryText.sans(
                      size: 11,
                      weight: FontWeight.w600,
                      color: BelfryColors.accentInk,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reminder.title,
                    textAlign: TextAlign.center,
                    style: BelfryText.sans(
                      size: 26,
                      weight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    BangkokTime.formatFull(widget.occurrence),
                    textAlign: TextAlign.center,
                    style: BelfryText.mono(size: 14, color: BelfryColors.ink2),
                  ),
                  if (reminder.note.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: BelfryColors.alarmNotes,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        reminder.note,
                        style: BelfryText.sans(
                          size: 14,
                          color: BelfryColors.ink2,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: BelfryButton(
                          label: 'Snooze 5m',
                          expand: true,
                          onPressed: widget.onSnooze,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BelfryButton(
                          label: 'Dismiss',
                          variant: BelfryButtonVariant.primary,
                          expand: true,
                          onPressed: widget.onDismiss,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pulsingBell() {
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ring — mirrors the prototype's box-shadow pulse.
              Container(
                width: 96 + 44 * t,
                height: 96 + 44 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BelfryColors.accent.withValues(
                    alpha: 0.5 * (1 - t),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: BelfryColors.accentSoft,
          ),
          child: const Icon(
            Icons.notifications_active_rounded,
            size: 44,
            color: BelfryColors.accentInk,
          ),
        ),
      ),
    );
  }
}
