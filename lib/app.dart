import 'package:flutter/material.dart';

import 'controller/belfry_controller.dart';
import 'screens/alarm_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/occurrence_calculator.dart';
import 'theme/belfry_theme.dart';

class BelfryApp extends StatelessWidget {
  const BelfryApp({super.key, required this.controller});

  final BelfryController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Belfry',
      debugShowCheckedModeBanner: false,
      theme: buildBelfryTheme(),
      scrollBehavior: const _BelfryScrollBehavior(),
      home: _RootScreen(controller: controller),
    );
  }
}

/// App-wide scroll behaviour: no scrollbars on any platform. Belfry's lists are
/// short and the desktop scrollbar chrome looks out of place against the
/// custom design.
class _BelfryScrollBehavior extends MaterialScrollBehavior {
  const _BelfryScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// Swaps between the splash, login and home screens based on session state,
/// and overlays the ringing alarm on top of everything.
class _RootScreen extends StatelessWidget {
  const _RootScreen({required this.controller});

  final BelfryController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        switch (controller.status) {
          case SessionStatus.booting:
            return const _Splash();
          case SessionStatus.loggedOut:
            return LoginScreen(controller: controller);
          case SessionStatus.loggedIn:
            final ringing = controller.ringingReminder;
            return Stack(
              children: [
                HomeScreen(controller: controller),
                if (ringing != null)
                  AlarmScreen(
                    reminder: ringing,
                    occurrence: OccurrenceCalculator.occurrenceOnOrBefore(
                      ringing.remindAt,
                      ringing.recurrence,
                    ),
                    onSnooze: controller.snoozeAlarm,
                    onDismiss: controller.dismissAlarm,
                  ),
              ],
            );
        }
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: BelfryColors.primary,
          ),
        ),
      ),
    );
  }
}
