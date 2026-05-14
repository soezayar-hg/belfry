/// How a reminder repeats. A reminder repeats forever until it is deleted or
/// its recurrence is set back to [none].
enum Recurrence {
  none('none', 'Once'),
  weekly('weekly', 'Weekly'),
  monthly('monthly', 'Monthly'),
  yearly('yearly', 'Yearly');

  const Recurrence(this.key, this.label);

  /// Wire value stored by the gateway.
  final String key;

  /// Human label shown in the form's segmented control.
  final String label;

  bool get repeats => this != Recurrence.none;

  static Recurrence fromKey(String? key) {
    for (final r in Recurrence.values) {
      if (r.key == key) return r;
    }
    return Recurrence.none;
  }
}
