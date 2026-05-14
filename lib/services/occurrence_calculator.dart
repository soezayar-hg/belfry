import '../models/lead_time.dart';
import '../models/recurrence.dart';
import 'bangkok_time.dart';

/// A single lead-time nudge resolved to an absolute instant.
typedef LeadTimeInstant = ({LeadTime lead, DateTime at});

/// Pure date math for reminders. The gateway stores only the anchor instant
/// and the recurrence rule; this derives the concrete occurrences and the
/// lead-time instants the scheduler arms. Everything is computed against
/// Bangkok wall-clock time so a "9:00" reminder stays at 9:00 forever.
class OccurrenceCalculator {
  OccurrenceCalculator._();

  /// Advance a UTC instant by one recurrence period, keeping the Bangkok
  /// wall-clock time. Monthly/yearly clamp to the last valid day of shorter
  /// months (e.g. Jan 31 → Feb 28). Returns null for [Recurrence.none].
  static DateTime? advance(DateTime utc, Recurrence recurrence) {
    if (!recurrence.repeats) return null;
    final b = BangkokTime.toBangkok(utc);

    switch (recurrence) {
      case Recurrence.weekly:
        return BangkokTime.fromParts(
          b.year,
          b.month,
          b.day + 7,
          b.hour,
          b.minute,
        );
      case Recurrence.monthly:
        var year = b.year;
        var month = b.month + 1;
        if (month > 12) {
          month = 1;
          year += 1;
        }
        final day = _clampDay(b.day, year, month);
        return BangkokTime.fromParts(year, month, day, b.hour, b.minute);
      case Recurrence.yearly:
        final year = b.year + 1;
        final day = _clampDay(b.day, year, b.month);
        return BangkokTime.fromParts(year, b.month, day, b.hour, b.minute);
      case Recurrence.none:
        return null;
    }
  }

  /// The next occurrence at or after [now]. For a non-recurring reminder this
  /// is simply the anchor (even if it is already in the past — a one-off keeps
  /// its original time). For a recurring reminder a past anchor is rolled
  /// forward period by period until it lands at or after [now].
  static DateTime nextOccurrence(
    DateTime anchor,
    Recurrence recurrence, {
    DateTime? now,
  }) {
    if (!recurrence.repeats) return anchor;
    final reference = (now ?? DateTime.now()).toUtc();

    var current = anchor;
    var guard = 0;
    while (current.isBefore(reference) && guard < 100000) {
      final next = advance(current, recurrence);
      if (next == null) break;
      current = next;
      guard += 1;
    }
    return current;
  }

  /// The occurrence at or before [now] — i.e. the one that has most recently
  /// fired. Used by the ringing screen to show which occurrence is alarming.
  /// For a non-recurring reminder this is always the anchor.
  static DateTime occurrenceOnOrBefore(
    DateTime anchor,
    Recurrence recurrence, {
    DateTime? now,
  }) {
    if (!recurrence.repeats) return anchor;
    final reference = (now ?? DateTime.now()).toUtc();
    if (anchor.isAfter(reference)) return anchor;

    var current = anchor;
    var guard = 0;
    while (guard < 100000) {
      final next = advance(current, recurrence);
      if (next == null || next.isAfter(reference)) break;
      current = next;
      guard += 1;
    }
    return current;
  }

  /// Resolve each enabled lead-time to an absolute instant relative to
  /// [occurrence]. Lead-times already in the past are still returned — the
  /// scheduler is responsible for skipping them rather than firing late.
  static List<LeadTimeInstant> leadTimeInstants(
    DateTime occurrence,
    Set<LeadTime> leadTimes,
  ) {
    final result = <LeadTimeInstant>[
      for (final lead in leadTimes)
        (lead: lead, at: occurrence.subtract(lead.offset)),
    ];
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  /// Last day of the given month, used to clamp recurrence overflow.
  static int _daysInMonth(int year, int month) {
    // Day 0 of the next month is the last day of `month`.
    return DateTime.utc(year, month + 1, 0).day;
  }

  static int _clampDay(int day, int year, int month) {
    final max = _daysInMonth(year, month);
    return day > max ? max : day;
  }
}
