import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/belfry_controller.dart';
import '../models/reminder.dart';
import '../services/bangkok_time.dart';
import '../services/occurrence_calculator.dart';
import '../services/scheduler_service.dart';
import '../theme/belfry_theme.dart';
import '../widgets/belfry_button.dart';
import '../widgets/reminder_card.dart';
import 'reminder_form_screen.dart';

/// A reminder paired with its resolved next occurrence, for display + sorting.
typedef _Row = ({Reminder reminder, DateTime occurrence});

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final BelfryController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _clock;
  DateTime _now = DateTime.now().toUtc();
  bool _tipDismissed = false;
  bool _macNotificationsDismissed = false;

  BelfryController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  List<_Row> _sortedRows() {
    final rows = <_Row>[
      for (final reminder in _controller.reminders)
        (
          reminder: reminder,
          occurrence: OccurrenceCalculator.nextOccurrence(
            reminder.remindAt,
            reminder.recurrence,
            now: _now,
          ),
        ),
    ];
    final upcoming = rows.where((r) => !r.occurrence.isBefore(_now)).toList()
      ..sort((a, b) => a.occurrence.compareTo(b.occurrence));
    final past = rows.where((r) => r.occurrence.isBefore(_now)).toList()
      ..sort((a, b) => b.occurrence.compareTo(a.occurrence));
    return [...upcoming, ...past];
  }

  Future<void> _openForm({Reminder? existing}) async {
    // A transparent, non-opaque route so the form's scrim composites over the
    // home screen instead of a black page background.
    final draft = await Navigator.of(context).push<Reminder>(
      PageRouteBuilder<Reminder>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReminderFormScreen(existing: existing),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (draft == null) return;
    try {
      await _controller.saveReminder(draft, id: existing?.id);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _confirmDelete(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BelfryColors.panel,
        title: Text(
          'Delete reminder?',
          style: BelfryText.sans(size: 17, weight: FontWeight.w600),
        ),
        content: Text(
          '"${reminder.title}" will be removed and its alarms cancelled.',
          style: BelfryText.sans(size: 14, color: BelfryColors.ink2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: BelfryText.sans(size: 14, color: BelfryColors.ink2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: BelfryText.sans(
                size: 14,
                weight: FontWeight.w600,
                color: BelfryColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _controller.deleteReminder(reminder.id);
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$error'.replaceFirst('ApiException: ', '')),
        backgroundColor: BelfryColors.ink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // `n` opens the new-reminder form. Scoped to the focus subtree, so it
    // doesn't fire while the form modal is open on top.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN): () => _openForm(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _content(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final rows = _sortedRows();
    final isEmpty = rows.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 24),
          const Divider(height: 1, color: BelfryColors.line),
          const SizedBox(height: 24),
          if (_showMacNotificationWarning()) ...[
            _macNotificationWarning(),
            const SizedBox(height: 18),
          ],
          if (!_tipDismissed && isEmpty) ...[
            _tipCard(),
            const SizedBox(height: 18),
          ],
          _addRow(rows.length),
          const SizedBox(height: 16),
          Expanded(
            child: _listPane(rows, isEmpty),
          ),
          const SizedBox(height: 18),
          Text(
            'All times shown in Asia/Bangkok (UTC+7).',
            textAlign: TextAlign.center,
            style: BelfryText.sans(size: 12, color: BelfryColors.ink3),
          ),
        ],
      ),
    );
  }

  Widget _listPane(List<_Row> rows, bool isEmpty) {
    if (_controller.isLoading) {
      return _loadingState();
    }

    if (_controller.loadError != null && isEmpty) {
      return _errorState();
    }

    if (isEmpty) {
      return _emptyState();
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        ..._reminderList(rows),
        if (_controller.loadError != null) ...[
          const SizedBox(height: 14),
          _inlineSyncError(),
        ],
      ],
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: BelfryColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: BelfryColors.onPrimary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Belfry',
                style: BelfryText.sans(
                  size: 22,
                  weight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: BelfryColors.success,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ASIA / BANGKOK',
                    style: BelfryText.sans(
                      size: 12,
                      weight: FontWeight.w500,
                      color: BelfryColors.ink2,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              BangkokTime.formatClock(_now),
              style: BelfryText.mono(size: 26, weight: FontWeight.w500),
            ),
            const SizedBox(height: 3),
            Text(
              BangkokTime.formatDate(_now).toUpperCase(),
              style: BelfryText.sans(
                size: 12,
                weight: FontWeight.w500,
                color: BelfryColors.ink2,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tipCard() {
    return Container(
      decoration: BoxDecoration(
        color: BelfryColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Add your first reminder and pick how early you want the '
              'nudges. The exact-time alarm rings until you dismiss it.',
              style: BelfryText.sans(
                size: 13,
                color: BelfryColors.accentInk,
                height: 1.45,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _tipDismissed = true),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 16, color: BelfryColors.accentInk),
            ),
          ),
        ],
      ),
    );
  }

  bool _showMacNotificationWarning() {
    if (kIsWeb || !Platform.isMacOS || _macNotificationsDismissed) {
      return false;
    }

    return SchedulerService.instance.lastDarwinPermissionGranted == false;
  }

  Widget _macNotificationWarning() {
    return Container(
      decoration: BoxDecoration(
        color: BelfryColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BelfryColors.danger.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: BelfryColors.danger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'macOS notifications are disabled for Belfry. Enable them in '
              'System Settings > Notifications > Belfry, or reminders will '
              'not fire outside the app.',
              style: BelfryText.sans(
                size: 13,
                color: BelfryColors.ink2,
                height: 1.45,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _macNotificationsDismissed = true),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 16, color: BelfryColors.ink3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addRow(int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count ${count == 1 ? 'REMINDER' : 'REMINDERS'}',
            style: BelfryText.sans(
              size: 11,
              color: BelfryColors.ink3,
              letterSpacing: 1.0,
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, color: BelfryColors.ink3),
          color: BelfryColors.panel,
          onSelected: (value) {
            if (value == 'refresh') _controller.syncReminders();
            if (value == 'signout') _controller.logout();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: Text('Refresh', style: BelfryText.sans(size: 14)),
            ),
            PopupMenuItem(
              value: 'signout',
              child: Text('Sign out', style: BelfryText.sans(size: 14)),
            ),
          ],
        ),
        const SizedBox(width: 4),
        Material(
          color: BelfryColors.primary,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => _openForm(),
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.add, color: BelfryColors.onPrimary, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _reminderList(List<_Row> rows) {
    return [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ReminderCard(
            reminder: row.reminder,
            occurrence: row.occurrence,
            now: _now,
            onEdit: () => _openForm(existing: row.reminder),
            onDelete: () => _confirmDelete(row.reminder),
          ),
        ),
    ];
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BelfryColors.line2, style: BorderStyle.solid),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 52),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nothing to remember — yet.',
              style: BelfryText.sans(size: 16, color: BelfryColors.ink2),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your first reminder and choose how early you want to be '
              'nudged.',
              textAlign: TextAlign.center,
              style: BelfryText.sans(size: 13, color: BelfryColors.ink3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: BelfryColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Container(
      decoration: BoxDecoration(
        color: BelfryColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BelfryColors.danger.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Text(
            'Couldn\'t load your reminders.',
            style: BelfryText.sans(size: 15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _controller.loadError ?? '',
            textAlign: TextAlign.center,
            style: BelfryText.sans(size: 13, color: BelfryColors.ink2),
          ),
          const SizedBox(height: 16),
          BelfryButton(
            label: 'Try again',
            variant: BelfryButtonVariant.primary,
            onPressed: _controller.retryLoad,
          ),
        ],
      ),
    );
  }

  Widget _inlineSyncError() {
    return Container(
      decoration: BoxDecoration(
        color: BelfryColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BelfryColors.danger.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing cached reminders — ${_controller.loadError}',
              style: BelfryText.sans(size: 12, color: BelfryColors.ink2),
            ),
          ),
          TextButton(
            onPressed: _controller.retryLoad,
            child: Text(
              'Retry',
              style: BelfryText.sans(
                size: 13,
                weight: FontWeight.w600,
                color: BelfryColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
