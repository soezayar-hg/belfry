import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/reminder.dart';

/// A simple JSON-file cache of the user's reminders. It mirrors the gateway
/// (the source of truth) so the alarm scheduler and the alarm screen keep
/// working when the app is offline or freshly launched.
class LocalStore {
  LocalStore._();

  static const _fileName = 'belfry_reminders.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Reads the cached reminders. Returns an empty list if nothing has been
  /// cached yet or the cache is unreadable — never throws.
  static Future<List<Reminder>> readReminders() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((row) => Reminder.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Overwrites the cache with [reminders].
  static Future<void> writeReminders(List<Reminder> reminders) async {
    final file = await _file();
    final encoded = jsonEncode(reminders.map((r) => r.toJson()).toList());
    await file.writeAsString(encoded, flush: true);
  }

  /// Drops the cache — called on sign-out.
  static Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort — a missing cache is the desired end state anyway.
    }
  }
}
