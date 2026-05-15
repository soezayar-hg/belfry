import 'package:belfry_app/services/scheduler_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractAlarmReminderId', () {
    test('returns the reminder id for alarm payloads', () {
      expect(
        SchedulerService.extractAlarmReminderId('alarm:rem_01jqabc'),
        'rem_01jqabc',
      );
    });

    test('returns null for non-alarm payloads', () {
      expect(
        SchedulerService.extractAlarmReminderId('lead:rem_01jqabc'),
        isNull,
      );
      expect(SchedulerService.extractAlarmReminderId(''), isNull);
      expect(SchedulerService.extractAlarmReminderId(null), isNull);
    });
  });
}
