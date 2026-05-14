/// A pre-reminder nudge fired before the exact time. Every lead-time fires a
/// normal notification with a sound; only the exact time rings as an alarm.
///
/// Durations mirror the prototype: "1 month before" is a flat 30 days.
enum LeadTime {
  oneMinute('1_min', '1 minute before', Duration(minutes: 1)),
  fiveMinutes('5_min', '5 minutes before', Duration(minutes: 5)),
  oneHour('1_hour', '1 hour before', Duration(hours: 1)),
  oneDay('1_day', '1 day before', Duration(days: 1)),
  oneWeek('1_week', '1 week before', Duration(days: 7)),
  oneMonth('1_month', '1 month before', Duration(days: 30));

  const LeadTime(this.key, this.label, this.offset);

  /// Wire value stored by the gateway in the `lead_times` array.
  final String key;

  /// Human label shown in the form, e.g. "1 hour before".
  final String label;

  /// How far before the exact time this nudge fires.
  final Duration offset;

  /// Label without the trailing " before", e.g. "1 hour" — used on card chips.
  String get shortLabel => label.replaceAll(' before', '');

  static LeadTime? fromKey(String key) {
    for (final l in LeadTime.values) {
      if (l.key == key) return l;
    }
    return null;
  }

  /// Parse a wire array of keys into an ordered set, ignoring unknown values.
  static Set<LeadTime> fromKeys(Iterable<dynamic> keys) {
    final result = <LeadTime>{};
    for (final raw in keys) {
      final lead = fromKey('$raw');
      if (lead != null) result.add(lead);
    }
    return result;
  }
}
