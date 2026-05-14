import 'package:flutter/material.dart';

import 'app.dart';
import 'controller/belfry_controller.dart';
import 'services/bangkok_time.dart';
import 'services/scheduler_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Belfry works entirely in Asia/Bangkok; load the tz database up front.
  BangkokTime.ensureInitialized();

  // Wire up local notifications + the exact-time alarm channel.
  await SchedulerService.instance.init();

  final controller = BelfryController();
  controller.attachScheduler();

  runApp(BelfryApp(controller: controller));

  // Restore the session and kick off the first sync after the first frame.
  await controller.bootstrap();
}
