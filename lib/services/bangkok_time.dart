import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Belfry works entirely in Asia/Bangkok (UTC+7, no DST). Reminder instants
/// are stored as UTC; this helper converts and formats them for display and
/// builds Bangkok wall-clock instants back into UTC.
class BangkokTime {
  BangkokTime._();

  static const String zoneName = 'Asia/Bangkok';

  static late tz.Location _location;
  static bool _ready = false;

  /// Must be called once at startup before any other method.
  static void ensureInitialized() {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _location = tz.getLocation(zoneName);
    _ready = true;
  }

  static tz.Location get location => _location;

  /// Current instant as a Bangkok-zoned datetime.
  static tz.TZDateTime now() => tz.TZDateTime.now(_location);

  /// Convert a UTC instant to a Bangkok-zoned datetime.
  static tz.TZDateTime toBangkok(DateTime utc) =>
      tz.TZDateTime.from(utc, _location);

  /// Build a Bangkok wall-clock instant and return it as UTC. Out-of-range
  /// day/hour/minute values normalise the same way `DateTime` does.
  static DateTime fromParts(int y, int m, int d, int h, int min) =>
      tz.TZDateTime(_location, y, m, d, h, min).toUtc();

  // ── Formatting (ported from the prototype) ──────────────────────────

  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static ({int h12, String ampm}) _to12h(int hour24) {
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    var h = hour24 % 12;
    if (h == 0) h = 12;
    return (h12: h, ampm: ampm);
  }

  /// e.g. "Thu 14 May 2026 · 11:34 PM".
  static String formatFull(DateTime utc) {
    final b = toBangkok(utc);
    final t = _to12h(b.hour);
    return '${_weekdays[b.weekday - 1]} ${b.day} ${_months[b.month - 1]} '
        '${b.year} · ${t.h12}:${_pad(b.minute)} ${t.ampm}';
  }

  /// e.g. "10:34:21 PM".
  static String formatClock(DateTime utc) {
    final b = toBangkok(utc);
    final t = _to12h(b.hour);
    return '${t.h12}:${_pad(b.minute)}:${_pad(b.second)} ${t.ampm}';
  }

  /// e.g. "Thu 14 May 2026".
  static String formatDate(DateTime utc) {
    final b = toBangkok(utc);
    return '${_weekdays[b.weekday - 1]} ${b.day} ${_months[b.month - 1]} '
        '${b.year}';
  }

  /// e.g. "11:34 PM".
  static String formatTime(DateTime utc) {
    final b = toBangkok(utc);
    final t = _to12h(b.hour);
    return '${t.h12}:${_pad(b.minute)} ${t.ampm}';
  }

  /// Coarse relative label, e.g. "in 59m" / "5m ago" / "in 3d".
  static String formatRelative(DateTime target, DateTime now) {
    final diff = target.difference(now);
    final past = diff.isNegative;
    final abs = diff.abs();
    String label;
    if (abs.inSeconds < 60) {
      label = '${abs.inSeconds}s';
    } else if (abs.inMinutes < 60) {
      label = '${abs.inMinutes}m';
    } else if (abs.inHours < 48) {
      label = '${abs.inHours}h';
    } else if (abs.inDays < 60) {
      label = '${abs.inDays}d';
    } else {
      label = '${abs.inDays ~/ 30}mo';
    }
    return past ? '$label ago' : 'in $label';
  }
}
