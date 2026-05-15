import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges to the native foreground service that keeps Belfry alive on
/// Android so the alarm receiver has CPU to post notifications. No-op on
/// non-Android platforms — macOS doesn't aggressively freeze cached apps.
class BelfryWatcherService {
  BelfryWatcherService._();

  static const _channel = MethodChannel('belfry/watcher');

  /// Starts the foreground "watcher" service. Safe to call repeatedly —
  /// startForegroundService on an already-running service is a no-op.
  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('start');
    } catch (error) {
      // Best-effort: a failure here doesn't break the app, just means
      // background alarms may be unreliable on aggressively-managed devices.
      debugPrint('Belfry: foreground service start failed: $error');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (error) {
      debugPrint('Belfry: foreground service stop failed: $error');
    }
  }
}
