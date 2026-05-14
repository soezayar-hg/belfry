import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Base URL for the Sozy Gateway. Override at build time with
/// `--dart-define=BELFRY_API_BASE_URL=https://...`.
const String apiBaseUrl = String.fromEnvironment(
  'BELFRY_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000/api/v1',
);

/// The HTTP client used for every gateway call. Swappable in tests with a
/// `MockClient`; production code leaves it as the default [http.Client].
http.Client httpClient = http.Client();

/// Raised for any non-2xx response or transport failure. [status] is `0` when
/// the request never reached the server (no connection, timeout, DNS, …).
class ApiException implements Exception {
  ApiException(this.message, this.status, [this.payload]);

  final String message;
  final int status;
  final Map<String, dynamic>? payload;

  bool get isUnauthorized => status == 401;
  bool get isNetworkError => status == 0;

  @override
  String toString() => 'ApiException($status): $message';
}

/// Thin `fetch`-style wrapper around the gateway. Mirrors the shape of
/// `expense_app/src/api/client.js`: a single entry point that attaches the
/// bearer token, decodes JSON, and turns failures into [ApiException]s.
Future<dynamic> apiRequest(
  String path, {
  String? token,
  String method = 'GET',
  Map<String, dynamic>? body,
}) async {
  final request = http.Request(method, Uri.parse('$apiBaseUrl$path'));
  request.headers['Accept'] = 'application/json';
  if (token != null) request.headers['Authorization'] = 'Bearer $token';
  if (body != null) {
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(body);
  }

  final http.Response response;
  try {
    final streamed = await httpClient.send(request).timeout(
      const Duration(seconds: 20),
    );
    response = await http.Response.fromStream(streamed);
  } on SocketException {
    throw ApiException('Can\'t reach the server. Check your connection.', 0);
  } on HttpException {
    throw ApiException('Can\'t reach the server. Check your connection.', 0);
  } catch (_) {
    throw ApiException('The request failed. Please try again.', 0);
  }

  final payload = (response.statusCode == 204 || response.body.isEmpty)
      ? null
      : _tryDecode(response.body);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ApiException(
      _extractMessage(payload) ?? 'The API request failed.',
      response.statusCode,
      payload is Map<String, dynamic> ? payload : null,
    );
  }

  return payload;
}

dynamic _tryDecode(String body) {
  try {
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}

/// Pull a human message out of a Laravel error body — either the top-level
/// `message` or the first validation error.
String? _extractMessage(dynamic payload) {
  if (payload is! Map<String, dynamic>) return null;
  final message = payload['message'];
  if (message is String && message.isNotEmpty) return message;
  final errors = payload['errors'];
  if (errors is Map && errors.isNotEmpty) {
    final first = errors.values.first;
    if (first is List && first.isNotEmpty) return '${first.first}';
  }
  return null;
}
