import 'dart:convert';

import 'package:belfry_app/api/belfry_api.dart';
import 'package:belfry_app/api/client.dart';
import 'package:belfry_app/models/lead_time.dart';
import 'package:belfry_app/models/recurrence.dart';
import 'package:belfry_app/models/reminder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A representative reminder in the gateway's snake_case wire shape.
Map<String, dynamic> wireReminder(String id) => {
  'id': id,
  'title': 'Pay electricity bill',
  'note': 'Account 4471',
  'remind_at': '2026-05-20T02:00:00.000000Z',
  'recurrence': 'monthly',
  'lead_times': ['1_day', '1_hour'],
  'created_at': '2026-05-14T09:12:00.000000Z',
  'updated_at': '2026-05-14T09:12:00.000000Z',
};

void main() {
  // Restore the real client after every test.
  tearDown(() => httpClient = http.Client());

  /// Installs a mock HTTP client driven by [handler].
  void mock(Future<http.Response> Function(http.Request request) handler) {
    httpClient = MockClient(handler);
  }

  http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  group('login', () {
    test('rejects an account without Belfry access with a 403', () {
      mock(
        (req) async => jsonResponse({
          'token': 'tok_1',
          'token_type': 'Bearer',
          'user': {'id': 1, 'email': 'a@b.com', 'apps': <dynamic>[]},
        }),
      );

      expect(
        () => BelfryApi.login(email: 'a@b.com', password: 'x'),
        throwsA(
          isA<ApiException>().having((e) => e.status, 'status', 403),
        ),
      );
    });

    test('accepts object-form user.apps containing belfry', () async {
      mock(
        (req) async => jsonResponse({
          'token': 'tok_2',
          'token_type': 'Bearer',
          'user': {
            'id': 1,
            'email': 'a@b.com',
            'apps': [
              {'key': 'belfry', 'name': 'Belfry'},
            ],
          },
        }),
      );

      final result = await BelfryApi.login(email: 'a@b.com', password: 'x');
      expect(result.token, 'tok_2');
      expect(result.user['email'], 'a@b.com');
    });

    test('accepts string-form user.apps containing belfry', () async {
      mock(
        (req) async => jsonResponse({
          'token': 'tok_3',
          'token_type': 'Bearer',
          'user': {
            'id': 1,
            'email': 'a@b.com',
            'apps': ['belfry'],
          },
        }),
      );

      final result = await BelfryApi.login(email: 'a@b.com', password: 'x');
      expect(result.token, 'tok_3');
    });

    test('sends email, password and a platform device_name', () async {
      late Map<String, dynamic> sentBody;
      mock((req) async {
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return jsonResponse({
          'token': 't',
          'token_type': 'Bearer',
          'user': {
            'email': 'a@b.com',
            'apps': ['belfry'],
          },
        });
      });

      await BelfryApi.login(email: 'a@b.com', password: 'secret');
      expect(sentBody['email'], 'a@b.com');
      expect(sentBody['password'], 'secret');
      expect(
        sentBody['device_name'],
        anyOf('belfry-macos', 'belfry-android'),
      );
    });

    test('surfaces a 422 (bad credentials) as an ApiException', () {
      mock(
        (req) async => jsonResponse({
          'message': 'The provided credentials are incorrect.',
          'errors': {
            'email': ['The provided credentials are incorrect.'],
          },
        }, 422),
      );

      expect(
        () => BelfryApi.login(email: 'a@b.com', password: 'wrong'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 422)
              .having(
                (e) => e.message,
                'message',
                'The provided credentials are incorrect.',
              ),
        ),
      );
    });
  });

  group('logout', () {
    test('completes when the gateway returns 200 with a JSON body', () {
      mock((req) async => jsonResponse({'message': 'Logged out.'}));
      expect(BelfryApi.logout('tok'), completes);
    });

    test('completes when the gateway returns 204', () {
      mock((req) async => http.Response('', 204));
      expect(BelfryApi.logout('tok'), completes);
    });
  });

  group('fetchReminders', () {
    test('combines every page into one list', () async {
      mock((req) async {
        final page = req.url.queryParameters['page'];
        if (page == '1') {
          return jsonResponse({
            'data': [wireReminder('rem_1'), wireReminder('rem_2')],
            'meta': {
              'current_page': 1,
              'last_page': 2,
              'per_page': 200,
              'total': 3,
            },
          });
        }
        return jsonResponse({
          'data': [wireReminder('rem_3')],
          'meta': {
            'current_page': 2,
            'last_page': 2,
            'per_page': 200,
            'total': 3,
          },
        });
      });

      final reminders = await BelfryApi.fetchReminders('tok');
      expect(reminders.map((r) => r.id), ['rem_1', 'rem_2', 'rem_3']);
    });

    test('requests per_page=200', () async {
      late Uri firstUri;
      mock((req) async {
        firstUri = req.url;
        return jsonResponse({
          'data': <dynamic>[],
          'meta': {'last_page': 1},
        });
      });

      await BelfryApi.fetchReminders('tok');
      expect(firstUri.queryParameters['per_page'], '200');
    });
  });

  group('createReminder', () {
    test('posts the write body and parses the response', () async {
      late Map<String, dynamic> sentBody;
      mock((req) async {
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return jsonResponse({'data': wireReminder('rem_new')}, 201);
      });

      final draft = Reminder(
        id: '',
        title: 'Pay rent',
        note: '',
        remindAt: DateTime.utc(2026, 5, 20, 2),
        recurrence: Recurrence.monthly,
        leadTimes: {LeadTime.oneDay},
      );
      final saved = await BelfryApi.createReminder('tok', draft);

      expect(sentBody['title'], 'Pay rent');
      expect(sentBody['recurrence'], 'monthly');
      expect(sentBody['lead_times'], ['1_day']);
      // The write body must not carry a server-assigned id.
      expect(sentBody.containsKey('id'), isFalse);
      expect(saved.id, 'rem_new');
    });
  });

  group('Reminder wire mapping', () {
    test('normalises a null note to an empty string', () {
      final reminder = Reminder.fromJson({
        'id': 'rem_x',
        'title': 'No note',
        'note': null,
        'remind_at': '2026-05-20T02:00:00.000000Z',
        'recurrence': 'none',
        'lead_times': <dynamic>[],
      });
      expect(reminder.note, '');
    });

    test('parses remind_at as UTC and maps lead-time keys', () {
      final reminder = Reminder.fromJson(wireReminder('rem_y'));
      expect(reminder.remindAt.isUtc, isTrue);
      expect(reminder.recurrence, Recurrence.monthly);
      expect(reminder.leadTimes, {LeadTime.oneDay, LeadTime.oneHour});
    });
  });
}
