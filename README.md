# Belfry

A simple reminder app — the Flutter client for the Sozy Gateway. Belfry records
things to remember and notifies you with in-app notifications and an alarm-style
ring at the exact time, with weekly / monthly / yearly recurrence and
configurable lead-time nudges.

Targets **Android** and **macOS**. Everything is shown in Asia/Bangkok.

## Documentation

- **`FRONTEND_INTEGRATION_GUIDE.md`** — the practical integration spec against
  the gateway as it behaves now. **Start here for any API work.**
- **`API_SPEC.md`** — the endpoint reference (request/response shapes, enums,
  errors).
- **`../docs/superpowers/specs/2026-05-14-belfry-design.md`** — the design
  rationale (architecture, recurrence model, alarm strategy).

## Project layout

```text
lib/
  api/         client.dart (HTTP wrapper, swappable for tests),
               belfry_api.dart (token-first calls, login access gate)
  controller/  belfry_controller.dart (session, sync, CRUD, alarm watcher)
  models/      reminder.dart, recurrence.dart, lead_time.dart
  services/    bangkok_time, occurrence_calculator, scheduler_service,
               local_store (JSON cache), secure_store (token)
  screens/     login, home, reminder form, alarm
  widgets/     buttons, reminder card, segmented control, datetime picker
  theme/       belfry_theme.dart (design tokens from the prototype)
assets/icon/   app-icon sources (.svg) — regenerate with flutter_launcher_icons
```

The gateway is the source of truth: it stores the reminder *anchor* and the
client derives the next occurrence locally (see the design doc). The client
pulls the full reminder list on sync and caches it to a JSON file so the alarm
scheduler keeps working offline.

## Commands

```bash
flutter run -d macos                 # run on macOS
flutter run -d <android-device>      # run on Android (needs Android SDK)
flutter test                         # unit + API tests
flutter analyze                      # static analysis
dart run flutter_launcher_icons      # regenerate app icons from assets/icon/
```

Point the app at a gateway with `--dart-define`:

```bash
flutter run -d macos --dart-define=BELFRY_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

## Status

- Flutter client complete: auth, reminder CRUD, recurrence, lead-time +
  exact-time scheduling via `flutter_local_notifications`, the ringing screen,
  offline JSON cache, retry affordance.
- Tests: `occurrence_calculator_test.dart` (recurrence math) and
  `belfry_api_test.dart` (wire mapping, login access gate, pagination).
- Pending native work: the Android Kotlin full-screen `AlarmActivity` with
  looping audio, and the macOS login-item background agent (see
  `scheduler_service.dart`).
