import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Persists the bearer token and cached user record in the platform secure
/// store (Keychain on macOS, EncryptedSharedPreferences on Android).
///
/// Every operation is **best-effort**: the OS keychain can be unavailable
/// (e.g. an ad-hoc-signed macOS build without the Keychain Sharing
/// entitlement). A failure to persist must never block sign-in — the
/// in-memory session still works for the current run; it just won't survive a
/// restart. Failures are logged, not thrown.
class SecureStore {
  SecureStore._();

  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'belfry_api_token';
  static const _userKey = 'belfry_api_user';
  static const _fallbackFileName = 'belfry_session.json';

  static Future<File> _fallbackFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fallbackFileName');
  }

  static bool get _useFileFallback => !kIsWeb && Platform.isMacOS;

  static Future<String?> readToken() async {
    if (_useFileFallback) {
      final session = await _readFallbackSession();
      final token = session?['token'];

      return token is String && token.isNotEmpty ? token : null;
    }

    try {
      return await _storage.read(key: _tokenKey);
    } catch (error) {
      debugPrint('SecureStore.readToken failed: $error');
      return null;
    }
  }

  static Future<void> writeToken(String token) async {
    if (_useFileFallback) {
      final session = await _readFallbackSession() ?? <String, dynamic>{};
      session['token'] = token;
      await _writeFallbackSession(session);
      return;
    }

    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (error) {
      debugPrint('SecureStore.writeToken failed: $error');
    }
  }

  static Future<Map<String, dynamic>?> readUser() async {
    if (_useFileFallback) {
      final session = await _readFallbackSession();
      final user = session?['user'];

      return user is Map<String, dynamic> ? user : null;
    }

    try {
      final raw = await _storage.read(key: _userKey);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (error) {
      debugPrint('SecureStore.readUser failed: $error');
      return null;
    }
  }

  static Future<void> writeUser(Map<String, dynamic> user) async {
    if (_useFileFallback) {
      final session = await _readFallbackSession() ?? <String, dynamic>{};
      session['user'] = user;
      await _writeFallbackSession(session);
      return;
    }

    try {
      await _storage.write(key: _userKey, value: jsonEncode(user));
    } catch (error) {
      debugPrint('SecureStore.writeUser failed: $error');
    }
  }

  /// Clears the session — called on sign-out and on any `401`.
  static Future<void> clear() async {
    if (_useFileFallback) {
      try {
        final file = await _fallbackFile();
        if (await file.exists()) {
          await file.delete();
        }
      } catch (error) {
        debugPrint('SecureStore.clear fallback failed: $error');
      }
      return;
    }

    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (error) {
      debugPrint('SecureStore.clear failed: $error');
    }
  }

  static Future<Map<String, dynamic>?> _readFallbackSession() async {
    try {
      final file = await _fallbackFile();
      if (!await file.exists()) {
        return null;
      }

      final raw = await file.readAsString();
      if (raw.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);

      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (error) {
      debugPrint('SecureStore.read fallback failed: $error');
      return null;
    }
  }

  static Future<void> _writeFallbackSession(
    Map<String, dynamic> session,
  ) async {
    try {
      final file = await _fallbackFile();
      await file.writeAsString(jsonEncode(session), flush: true);
    } catch (error) {
      debugPrint('SecureStore.write fallback failed: $error');
    }
  }
}
