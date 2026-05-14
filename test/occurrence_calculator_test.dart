import 'package:belfry_app/models/lead_time.dart';
import 'package:belfry_app/models/recurrence.dart';
import 'package:belfry_app/services/bangkok_time.dart';
import 'package:belfry_app/services/occurrence_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(BangkokTime.ensureInitialized);

  // A Bangkok wall-clock instant, returned as UTC.
  DateTime bkk(int y, int m, int d, [int h = 9, int min = 0]) =>
      BangkokTime.fromParts(y, m, d, h, min);

  group('advance', () {
    test('weekly adds exactly 7 days, same wall-clock time', () {
      expect(
        OccurrenceCalculator.advance(bkk(2026, 5, 14), Recurrence.weekly),
        bkk(2026, 5, 21),
      );
    });

    test('monthly keeps day-of-month and rolls the year', () {
      expect(
        OccurrenceCalculator.advance(bkk(2026, 12, 15), Recurrence.monthly),
        bkk(2027, 1, 15),
      );
    });

    test('monthly clamps to the last day of a shorter month', () {
      // Jan 31 → Feb (2026 is not a leap year) → Feb 28.
      expect(
        OccurrenceCalculator.advance(bkk(2026, 1, 31), Recurrence.monthly),
        bkk(2026, 2, 28),
      );
    });

    test('yearly clamps Feb 29 onto a non-leap year', () {
      // 2024 is a leap year, 2025 is not.
      expect(
        OccurrenceCalculator.advance(bkk(2024, 2, 29), Recurrence.yearly),
        bkk(2025, 2, 28),
      );
    });

    test('none does not advance', () {
      expect(
        OccurrenceCalculator.advance(bkk(2026, 5, 14), Recurrence.none),
        isNull,
      );
    });
  });

  group('nextOccurrence', () {
    test('non-recurring reminder always returns the anchor', () {
      final anchor = bkk(2020, 1, 1);
      expect(
        OccurrenceCalculator.nextOccurrence(
          anchor,
          Recurrence.none,
          now: bkk(2026, 5, 14),
        ),
        anchor,
      );
    });

    test('recurring reminder rolls a past anchor forward to >= now', () {
      // Weekly anchored 1 May; "now" is 20 May noon → next is 22 May.
      final next = OccurrenceCalculator.nextOccurrence(
        bkk(2026, 5, 1),
        Recurrence.weekly,
        now: bkk(2026, 5, 20, 12, 0),
      );
      expect(next, bkk(2026, 5, 22));
    });

    test('recurring reminder in the future is returned unchanged', () {
      final anchor = bkk(2026, 6, 1);
      expect(
        OccurrenceCalculator.nextOccurrence(
          anchor,
          Recurrence.monthly,
          now: bkk(2026, 5, 14),
        ),
        anchor,
      );
    });
  });

  group('leadTimeInstants', () {
    test('subtracts each offset and returns them earliest-first', () {
      final occurrence = bkk(2026, 5, 14, 12, 0);
      final instants = OccurrenceCalculator.leadTimeInstants(
        occurrence,
        {LeadTime.oneHour, LeadTime.oneDay},
      );
      expect(instants.map((i) => i.lead).toList(), [
        LeadTime.oneDay,
        LeadTime.oneHour,
      ]);
      expect(instants[0].at, occurrence.subtract(const Duration(days: 1)));
      expect(instants[1].at, occurrence.subtract(const Duration(hours: 1)));
    });

    test('empty lead-time set yields no instants', () {
      expect(
        OccurrenceCalculator.leadTimeInstants(bkk(2026, 5, 14), const {}),
        isEmpty,
      );
    });
  });
}
