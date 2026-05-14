import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  static Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (error) {
      debugPrint('SecureStore.readToken failed: $error');
      return null;
    }
  }

  static Future<void> writeToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (error) {
      debugPrint('SecureStore.writeToken failed: $error');
    }
  }

  static Future<Map<String, dynamic>?> readUser() async {
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
    try {
      await _storage.write(key: _userKey, value: jsonEncode(user));
    } catch (error) {
      debugPrint('SecureStore.writeUser failed: $error');
    }
  }

  /// Clears the session — called on sign-out and on any `401`.
  static Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (error) {
      debugPrint('SecureStore.clear failed: $error');
    }
  }
}
