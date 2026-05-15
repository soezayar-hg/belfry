import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/belfry_api.dart';
import '../api/client.dart';
import '../models/reminder.dart';
import '../services/local_store.dart';
import '../services/occurrence_calculator.dart';
import '../services/scheduler_service.dart';
import '../services/secure_store.dart';

enum SessionStatus { booting, loggedOut, loggedIn }

/// Top-level app state: the session, the reminder list, the sync lifecycle,
/// and the currently-ringing alarm. Mirrors the single `App` component in the
/// prototype — screens listen to this and call its methods.
class BelfryController extends ChangeNotifier {
  static const Duration _foregroundAlarmTolerance = Duration(seconds: 20);

  SessionStatus status = SessionStatus.booting;
  Map<String, dynamic>? user;
  List<Reminder> reminders = const [];

  /// True while the initial post-login fetch is in flight with nothing cached
  /// to show yet.
  bool isLoading = false;

  /// Set when a sync fails for a non-auth reason; the UI offers a retry.
  String? loadError;

  /// The reminder whose exact-time alarm is currently ringing, if any.
  Reminder? ringingReminder;

  String? _token;
  String? get token => _token;

  /// Watches for exact-time alarms coming due while the app is in the
  /// foreground, so the ringing screen appears without relying on the OS
  /// notification round-trip.
  Timer? _watcher;

  /// Occurrence keys that have already rung this session — prevents an alarm
  /// re-firing after it is dismissed or snoozed.
  final Set<String> _firedOccurrenceKeys = {};
  String? _pendingAlarmReminderId;

  String get displayName {
    final name = user?['name'];
    if (name is String && name.isNotEmpty) return name;
    final email = user?['email'];
    if (email is String && email.isNotEmpty) return email;
    return 'You';
  }

  /// Wires the scheduler's foreground-alarm callback into this controller.
  void attachScheduler() {
    SchedulerService.instance.onAlarm = _handleAlarmFired;
    _pendingAlarmReminderId = SchedulerService.instance.pendingAlarmReminderId;
  }

  // ── Session lifecycle ───────────────────────────────────────────────

  Future<void> bootstrap() async {
    final saved = await SecureStore.readToken();
    if (saved == null) {
      status = SessionStatus.loggedOut;
      notifyListeners();
      return;
    }
    _token = saved;
    user = await SecureStore.readUser();
    status = SessionStatus.loggedIn;
    _startWatcher();

    // Show cached reminders instantly, then sync.
    reminders = await LocalStore.readReminders();
    isLoading = reminders.isEmpty;
    _applyPendingAlarmIfPossible();
    notifyListeners();
    await syncReminders();
  }

  Future<void> login(String email, String password) async {
    final result = await BelfryApi.login(email: email, password: password);
    _token = result.token;
    user = result.user;
    await SecureStore.writeToken(result.token);
    await SecureStore.writeUser(result.user);

    status = SessionStatus.loggedIn;
    _startWatcher();
    reminders = await LocalStore.readReminders();
    isLoading = reminders.isEmpty;
    _applyPendingAlarmIfPossible();
    notifyListeners();
    await syncReminders();
  }

  Future<void> logout() async {
    final current = _token;
    if (current != null) {
      try {
        await BelfryApi.logout(current);
      } catch (_) {
        // Sign out locally even if the network call fails.
      }
    }
    await _clearSession();
  }

  Future<void> _clearSession() async {
    _stopWatcher();
    _firedOccurrenceKeys.clear();
    _token = null;
    user = null;
    reminders = const [];
    loadError = null;
    ringingReminder = null;
    isLoading = false;
    await SecureStore.clear();
    await LocalStore.clear();
    await SchedulerService.instance.cancelAll();
    status = SessionStatus.loggedOut;
    notifyListeners();
  }

  // ── Reminder data ───────────────────────────────────────────────────

  Future<void> syncReminders() async {
    final current = _token;
    if (current == null) return;
    loadError = null;
    notifyListeners();

    final List<Reminder> fresh;
    try {
      fresh = await BelfryApi.fetchReminders(current);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _clearSession();
        return;
      }
      // Keep showing whatever is cached; surface a retry affordance.
      loadError = error.message;
      isLoading = false;
      notifyListeners();
      return;
    }

    reminders = fresh;
    isLoading = false;
    _applyPendingAlarmIfPossible();
    notifyListeners();

    // Caching and OS scheduling are best-effort — a failure here (e.g. a
    // platform notification quirk) must never bubble up and break the session.
    try {
      await LocalStore.writeReminders(fresh);
      await SchedulerService.instance.reschedule(fresh);
    } catch (error) {
      debugPrint('Belfry: post-sync cache/schedule failed: $error');
    }
  }

  /// Retries the initial load after a failure.
  Future<void> retryLoad() async {
    isLoading = reminders.isEmpty;
    notifyListeners();
    await syncReminders();
  }

  /// Creates a reminder (when [id] is null) or updates an existing one. The
  /// write goes to the gateway first, then the local cache and the scheduler.
  Future<void> saveReminder(Reminder draft, {String? id}) async {
    final current = _token;
    if (current == null) return;

    final Reminder saved;
    if (id == null) {
      saved = await BelfryApi.createReminder(current, draft);
      reminders = [...reminders, saved];
    } else {
      saved = await BelfryApi.updateReminder(current, id, draft);
      reminders = [for (final r in reminders) r.id == id ? saved : r];
    }
    await LocalStore.writeReminders(reminders);
    await SchedulerService.instance.reschedule(reminders);
    notifyListeners();
  }

  Future<void> deleteReminder(String id) async {
    final current = _token;
    if (current == null) return;

    await BelfryApi.deleteReminder(current, id);
    reminders = [
      for (final r in reminders)
        if (r.id != id) r,
    ];
    if (ringingReminder?.id == id) ringingReminder = null;
    await LocalStore.writeReminders(reminders);
    await SchedulerService.instance.reschedule(reminders);
    notifyListeners();
  }

  // ── Alarm handling ──────────────────────────────────────────────────

  void _handleAlarmFired(String reminderId) {
    _pendingAlarmReminderId = reminderId;
    _applyPendingAlarmIfPossible();
  }

  void _applyPendingAlarmIfPossible() {
    final reminderId = _pendingAlarmReminderId;
    if (reminderId == null) {
      return;
    }

    Reminder? match;
    for (final r in reminders) {
      if (r.id == reminderId) {
        match = r;
        break;
      }
    }

    if (match == null) {
      return;
    }

    _pendingAlarmReminderId = null;
    SchedulerService.instance.clearPendingAlarmReminderId();
    ringingReminder = match;
    notifyListeners();
  }

  /// Dismisses the ringing alarm. For a recurring reminder the scheduler
  /// re-arms the next occurrence automatically (the anchor never moves, so the
  /// occurrence calculator already rolls forward past "now").
  Future<void> dismissAlarm() async {
    ringingReminder = null;
    notifyListeners();
    await SchedulerService.instance.reschedule(reminders);
  }

  /// Snoozes the ringing alarm — arms a one-off alarm five minutes out.
  Future<void> snoozeAlarm() async {
    final ringing = ringingReminder;
    if (ringing == null) return;
    ringingReminder = null;
    notifyListeners();
    await SchedulerService.instance.snooze(ringing);
    await SchedulerService.instance.reschedule(reminders);
  }

  // ── Foreground alarm watcher ────────────────────────────────────────

  void _startWatcher() {
    _watcher?.cancel();
    _watcher = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkDueAlarms(),
    );
  }

  void _stopWatcher() {
    _watcher?.cancel();
    _watcher = null;
  }

  /// Rings the first reminder whose exact occurrence has just come due and has
  /// not yet been acknowledged this session. A short tolerance absorbs timer
  /// drift without letting stale reminders fire minutes late.
  void _checkDueAlarms() {
    if (ringingReminder != null) return;
    final now = DateTime.now().toUtc();

    for (final reminder in reminders) {
      final occurrence = OccurrenceCalculator.occurrenceOnOrBefore(
        reminder.remindAt,
        reminder.recurrence,
        now: now,
      );
      final age = now.difference(occurrence);
      if (age.isNegative || age > _foregroundAlarmTolerance) continue;

      final key = '${reminder.id}@${occurrence.millisecondsSinceEpoch}';
      if (_firedOccurrenceKeys.contains(key)) continue;

      _firedOccurrenceKeys.add(key);
      ringingReminder = reminder;
      notifyListeners();
      return;
    }
  }

  @override
  void dispose() {
    _stopWatcher();
    super.dispose();
  }
}
