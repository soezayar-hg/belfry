import 'lead_time.dart';
import 'recurrence.dart';

/// A reminder definition. The gateway stores this as the single source of
/// truth; [remindAt] is the immutable *anchor* — the client derives the next
/// occurrence locally (see `OccurrenceCalculator`).
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.note,
    required this.remindAt,
    required this.recurrence,
    required this.leadTimes,
    this.createdAt,
    this.updatedAt,
  });

  /// ULID, prefixed `rem_`. Assigned by the gateway.
  final String id;

  final String title;

  /// Optional free-text note. Empty string when absent.
  final String note;

  /// The anchor datetime, in UTC. Stored UTC; displayed in Asia/Bangkok.
  final DateTime remindAt;

  final Recurrence recurrence;

  /// Enabled lead-time nudges. The exact-time alarm is always on and is not
  /// part of this set.
  final Set<LeadTime> leadTimes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Reminder copyWith({
    String? id,
    String? title,
    String? note,
    DateTime? remindAt,
    Recurrence? recurrence,
    Set<LeadTime>? leadTimes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      remindAt: remindAt ?? this.remindAt,
      recurrence: recurrence ?? this.recurrence,
      leadTimes: leadTimes ?? this.leadTimes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Parse the gateway's snake_case wire shape. Also used for the local JSON
  /// cache, which stores the same shape.
  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
      remindAt: DateTime.parse(json['remind_at'] as String).toUtc(),
      recurrence: Recurrence.fromKey(json['recurrence'] as String?),
      leadTimes: LeadTime.fromKeys(
        (json['lead_times'] as List?) ?? const [],
      ),
      createdAt: _parseOptional(json['created_at']),
      updatedAt: _parseOptional(json['updated_at']),
    );
  }

  /// Serialise to the gateway's snake_case wire shape (also the cache shape).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'recurrence': recurrence.key,
      'lead_times': leadTimes.map((l) => l.key).toList(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }

  /// The request body for create / update calls — only the user-editable
  /// fields, no server-assigned id or timestamps.
  Map<String, dynamic> toWriteBody() {
    return {
      'title': title,
      'note': note,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'recurrence': recurrence.key,
      'lead_times': leadTimes.map((l) => l.key).toList(),
    };
  }

  static DateTime? _parseOptional(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toUtc();
    }
    return null;
  }
}
