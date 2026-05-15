import 'package:flutter/material.dart';

import 'app.dart';
import 'controller/belfry_controller.dart';
import 'services/bangkok_time.dart';
import 'services/foreground_service.dart';
import 'services/scheduler_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Belfry works entirely in Asia/Bangkok; load the tz database up front.
  BangkokTime.ensureInitialized();

  // Wire up local notifications + the exact-time alarm channel.
  await SchedulerService.instance.init();

  // Promote the process to foreground-service priority on Android so the
  // alarm receiver has CPU budget to post notifications when reminders fire.
  // No-op on macOS. See BelfryService.kt for the why.
  await BelfryWatcherService.start();

  final controller = BelfryController();
  controller.attachScheduler();

  runApp(BelfryApp(controller: controller));

  // Restore the session and kick off the first sync after the first frame.
  await controller.bootstrap();
}
