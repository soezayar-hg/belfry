import 'dart:io';

import '../models/reminder.dart';
import 'client.dart';

/// Result of a successful login: the bearer token plus the cached user record.
class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;
}

/// Backend-shaped API surface for Belfry. Talks to the Laravel gateway under
/// `/api/v1/apps/belfry/*`. The wire format is snake_case; [Reminder] handles
/// the conversion. Every call takes the bearer token as its first argument.
class BelfryApi {
  BelfryApi._();

  /// App key used for the gateway's per-app access check.
  static const String appKey = 'belfry';

  // ── Auth ────────────────────────────────────────────────────────────

  /// Logs in against the shared gateway endpoint, then confirms the user has
  /// been granted Belfry access — rejecting with a `403` [ApiException] if not.
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final payload = await apiRequest(
      '/auth/login',
      method: 'POST',
      body: {
        'email': email,
        'password': password,
        'device_name': deviceName,
      },
    ) as Map<String, dynamic>;

    final user = payload['user'];
    if (user is! Map<String, dynamic> || !_hasBelfryAccess(user)) {
      throw ApiException(
        'This account does not have access to Belfry.',
        403,
        payload,
      );
    }

    final token = payload['token'];
    if (token is! String || token.isEmpty) {
      throw ApiException('The server did not return a token.', 502, payload);
    }

    return AuthResult(token: token, user: user);
  }

  static Future<void> logout(String token) async {
    await apiRequest('/auth/logout', token: token, method: 'POST');
  }

  // ── Reminders ───────────────────────────────────────────────────────

  /// Fetches every reminder for the user, following pagination. The dataset
  /// is small, so pulling all pages on each sync is fine.
  static Future<List<Reminder>> fetchReminders(String token) async {
    final reminders = <Reminder>[];
    var page = 1;
    var lastPage = 1;

    do {
      final payload = await apiRequest(
        '/apps/belfry/reminders?per_page=200&page=$page',
        token: token,
      ) as Map<String, dynamic>;

      final data = (payload['data'] as List?) ?? const [];
      reminders.addAll(
        data.map((row) => Reminder.fromJson(row as Map<String, dynamic>)),
      );

      final meta = payload['meta'];
      lastPage = (meta is Map && meta['last_page'] is int)
          ? meta['last_page'] as int
          : page;
      page += 1;
    } while (page <= lastPage);

    return reminders;
  }

  static Future<Reminder> createReminder(
    String token,
    Reminder reminder,
  ) async {
    final payload = await apiRequest(
      '/apps/belfry/reminders',
      token: token,
      method: 'POST',
      body: reminder.toWriteBody(),
    ) as Map<String, dynamic>;
    return Reminder.fromJson(payload['data'] as Map<String, dynamic>);
  }

  static Future<Reminder> updateReminder(
    String token,
    String id,
    Reminder reminder,
  ) async {
    final payload = await apiRequest(
      '/apps/belfry/reminders/$id',
      token: token,
      method: 'PATCH',
      body: reminder.toWriteBody(),
    ) as Map<String, dynamic>;
    return Reminder.fromJson(payload['data'] as Map<String, dynamic>);
  }

  static Future<void> deleteReminder(String token, String id) async {
    await apiRequest(
      '/apps/belfry/reminders/$id',
      token: token,
      method: 'DELETE',
    );
  }

  // ── Internals ───────────────────────────────────────────────────────

  /// Device name sent on login so the gateway can label the token. Belfry is
  /// only built for Android and macOS.
  static String get deviceName =>
      Platform.isMacOS ? 'belfry-macos' : 'belfry-android';

  /// The gateway may serialise `user.apps` as bare key strings or as objects
  /// with `key`/`name`. Accept either, matching the sibling apps' logic.
  static bool _hasBelfryAccess(Map<String, dynamic> user) {
    final apps = user['apps'];
    if (apps is! List) return false;

    for (final app in apps) {
      if (app is String && app.toLowerCase() == appKey) return true;
      if (app is Map) {
        final key = app['key'];
        if (key is String && key.toLowerCase() == appKey) return true;
        final name = app['name'];
        if (name is String && name.toLowerCase() == 'belfry') return true;
      }
    }
    return false;
  }
}
