import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/lead_time.dart';
import '../models/reminder.dart';
import 'bangkok_time.dart';
import 'occurrence_calculator.dart';

/// Schedules OS-level notifications and the exact-time alarm for reminders.
///
/// Strategy (per the design spec): a *rolling window* — on every reschedule we
/// cancel everything and re-arm, for each reminder, the next occurrence's
/// exact-time alarm plus its still-future lead-times. The dataset is small so
/// a full re-arm is simplest and keeps us well under any OS pending-limit.
///
/// The lead-times fire as ordinary notifications with a sound; the exact time
/// fires as a max-importance, full-screen-intent "alarm" notification. The
/// true ring-until-dismissed AlarmActivity is native Kotlin (see
/// `android/.../AlarmActivity` — pending) — this layer schedules it and
/// surfaces the ringing screen when the app process is alive.
class SchedulerService {
  SchedulerService._();

  static final SchedulerService instance = SchedulerService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Invoked when an exact-time alarm notification is tapped, so the UI can
  /// present the ringing screen. The foreground watcher in the controller
  /// covers the case where the app is already open.
  void Function(String reminderId)? onAlarm;

  static const String _alarmPayloadPrefix = 'alarm:';
  static const String _leadChannelId = 'belfry_leadtime';
  static const String _alarmChannelId = 'belfry_alarm';

  // ── Setup ───────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_ready) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _handleResponse,
    );

    await _configureAndroid();
    _ready = true;
  }

  Future<void> _configureAndroid() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.requestNotificationsPermission();
    await android.requestExactAlarmsPermission();

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _leadChannelId,
        'Reminder nudges',
        description: 'Lead-time reminders before the exact time.',
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _alarmChannelId,
        'Reminder alarms',
        description: 'The exact-time alarm that rings until dismissed.',
        importance: Importance.max,
        playSound: true,
      ),
    );
  }

  void _handleResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith(_alarmPayloadPrefix)) {
      onAlarm?.call(payload.substring(_alarmPayloadPrefix.length));
    }
  }

  // ── Scheduling ──────────────────────────────────────────────────────

  /// Cancels everything and re-arms the next occurrence + lead-times for each
  /// reminder.
  Future<void> reschedule(List<Reminder> reminders) async {
    if (!_ready) await init();
    await _plugin.cancelAll();

    final now = DateTime.now().toUtc();
    for (final reminder in reminders) {
      final occurrence = OccurrenceCalculator.nextOccurrence(
        reminder.remindAt,
        reminder.recurrence,
        now: now,
      );

      if (occurrence.isAfter(now)) {
        await _scheduleAlarm(reminder, occurrence);
      }

      for (final instant in OccurrenceCalculator.leadTimeInstants(
        occurrence,
        reminder.leadTimes,
      )) {
        if (instant.at.isAfter(now)) {
          await _scheduleLead(reminder, instant.lead, instant.at);
        }
      }
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// Arms a one-off alarm five minutes out for a snoozed reminder.
  Future<void> snooze(Reminder reminder) async {
    if (!_ready) await init();
    final at = DateTime.now().toUtc().add(const Duration(minutes: 5));
    await _plugin.zonedSchedule(
      id: _notificationId(reminder.id, 99),
      title: reminder.title,
      body: reminder.note.isEmpty ? 'Snoozed reminder' : reminder.note,
      scheduledDate: BangkokTime.toBangkok(at),
      notificationDetails: _alarmDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: '$_alarmPayloadPrefix${reminder.id}',
    );
  }

  Future<void> _scheduleAlarm(Reminder reminder, DateTime occurrence) async {
    await _plugin.zonedSchedule(
      id: _notificationId(reminder.id, 0),
      title: reminder.title,
      body: reminder.note.isEmpty ? 'It\'s time.' : reminder.note,
      scheduledDate: BangkokTime.toBangkok(occurrence),
      notificationDetails: _alarmDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: '$_alarmPayloadPrefix${reminder.id}',
    );
  }

  Future<void> _scheduleLead(
    Reminder reminder,
    LeadTime lead,
    DateTime at,
  ) async {
    await _plugin.zonedSchedule(
      id: _notificationId(reminder.id, lead.index + 1),
      title: reminder.title,
      body: '${lead.shortLabel} until "${reminder.title}"',
      scheduledDate: BangkokTime.toBangkok(at),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _leadChannelId,
          'Reminder nudges',
          channelDescription: 'Lead-time reminders before the exact time.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'lead:${reminder.id}',
    );
  }

  NotificationDetails _alarmDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _alarmChannelId,
        'Reminder alarms',
        channelDescription:
            'The exact-time alarm that rings until dismissed.',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  /// A stable, 31-bit-safe notification id derived from the reminder id and a
  /// slot (0 = exact alarm, 1..6 = lead-times, 99 = snooze).
  int _notificationId(String reminderId, int slot) {
    return (reminderId.hashCode & 0x3FFFFF) * 100 + slot;
  }
}
