# Belfry Frontend Integration Guide

This is the **practical frontend spec** for Belfry based on the **current**
Laravel gateway implementation in `api_gateway/`.

Use this document for Flutter integration work. It intentionally documents the
backend **as it behaves now**, not just the ideal contract in `API_SPEC.md`.

## Base setup

- Base URL in development: `http://127.0.0.1:8000/api/v1`
- Override with:
  - `--dart-define=BELFRY_API_BASE_URL=https://your-host/api/v1`
- Auth style:
  - Laravel Sanctum bearer token
  - send `Authorization: Bearer <token>` on every request except login
- App access key:
  - `belfry`
- App routes are protected by:
  - `auth:sanctum`
  - `throttle:belfry-api`
  - `app.access:belfry`

## Current backend realities

These are the parts the frontend must account for.

### Shared login response

`POST /auth/login` returns `200` on success with:

```json
{
  "token": "12|plaintextSanctumToken...",
  "token_type": "Bearer",
  "user": {
    "id": 1,
    "name": "Sozy",
    "email": "user@example.com",
    "is_admin": false,
    "apps": [
      { "key": "belfry", "name": "Belfry" }
    ]
  }
}
```

Notes:
- `user.is_active` is **not currently included** in the response.
- `user.apps` currently comes back as app objects, but Belfry should continue to
  tolerate either:
  - bare strings like `"belfry"`
  - objects like `{ "key": "belfry", "name": "Belfry" }`
- wrong credentials and inactive users return `422`, not `401`

### Logout response

`POST /auth/logout` currently returns:

```json
{ "message": "Logged out." }
```

The frontend should tolerate:
- `204 No Content`
- `200` with a JSON body
- `200` with an empty body

### Reminder timestamps

The reminder API returns timestamps in UTC ISO-8601 and this is the format the
Flutter app should treat as the source of truth.

Example:

```json
"remind_at": "2026-05-20T02:00:00.000000Z"
```

The app should:
- parse API timestamps as UTC
- convert to Asia/Bangkok for display
- always send `remind_at` back in UTC ISO-8601

## Auth flow

### Login

`POST /auth/login`

Request:

```json
{
  "email": "user@example.com",
  "password": "secret",
  "device_name": "belfry-macos"
}
```

`device_name` values Belfry should use:
- `belfry-macos`
- `belfry-android`

Frontend rules:
- after login succeeds, inspect `user.apps`
- if the account does not have `belfry` access, reject locally with a
  frontend-generated `403` style error:
  - `This account does not have access to Belfry.`
- store:
  - bearer token
  - cached user payload

### Logout

`POST /auth/logout`

Headers:

```http
Authorization: Bearer <token>
Accept: application/json
```

Frontend rule:
- regardless of whether the backend returns `204` or `200`, clear the local
  session on success

## Reminder endpoints

All Belfry reminder endpoints are under:

- `/apps/belfry/reminders`

Wire format is snake_case. The Flutter app should continue converting between
snake_case at the API layer and camelCase in app code.

### Reminder object

```json
{
  "id": "rem_01jqabc8z9k2m4n6p8r0s2t4v6",
  "title": "Pay electricity bill",
  "note": "Account 4471-220",
  "remind_at": "2026-05-20T02:00:00.000000Z",
  "recurrence": "monthly",
  "lead_times": ["1_day", "1_hour"],
  "created_at": "2026-05-14T09:12:00.000000Z",
  "updated_at": "2026-05-14T09:12:00.000000Z"
}
```

Field rules:
- `id`: server-assigned string, prefixed `rem_`
- `title`: required, max 255
- `note`: nullable string
- `remind_at`: required UTC ISO-8601 string
- `recurrence`: one of `none`, `weekly`, `monthly`, `yearly`
- `lead_times`: array containing any of:
  - `1_min`
  - `5_min`
  - `1_hour`
  - `1_day`
  - `1_week`
  - `1_month`

Important behavior:
- recurring reminders keep their original anchor `remind_at`
- the backend does not roll recurring reminders forward
- next occurrence is computed by the client
- dismissing or snoozing is client-side only

### Fetch reminders

`GET /apps/belfry/reminders?page=1&per_page=200`

Success response:

```json
{
  "data": [
    {
      "id": "rem_01jqabc8z9k2m4n6p8r0s2t4v6",
      "title": "Pay electricity bill",
      "note": "Account 4471-220",
      "remind_at": "2026-05-20T02:00:00.000000Z",
      "recurrence": "monthly",
      "lead_times": ["1_day", "1_hour"],
      "created_at": "2026-05-14T09:12:00.000000Z",
      "updated_at": "2026-05-14T09:12:00.000000Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 200,
    "total": 1
  }
}
```

Frontend rule:
- keep fetching pages until `page > last_page`
- the backend default is `per_page=50`
- Belfry should keep requesting `per_page=200`

### Create reminder

`POST /apps/belfry/reminders`

Request:

```json
{
  "title": "Pay electricity bill",
  "note": "Account 4471-220",
  "remind_at": "2026-05-20T02:00:00.000000Z",
  "recurrence": "monthly",
  "lead_times": ["1_day", "1_hour"]
}
```

Success:

```json
{
  "data": {
    "id": "rem_01jq...",
    "title": "Pay electricity bill",
    "note": "Account 4471-220",
    "remind_at": "2026-05-20T02:00:00.000000Z",
    "recurrence": "monthly",
    "lead_times": ["1_day", "1_hour"],
    "created_at": "2026-05-14T09:12:00.000000Z",
    "updated_at": "2026-05-14T09:12:00.000000Z"
  }
}
```

Validation expectations:
- `title` required
- `note` optional
- `remind_at` required
- `recurrence` defaults to `none` if omitted
- `lead_times` defaults to `[]` if omitted

### Update reminder

`PATCH /apps/belfry/reminders/{id}`

The backend supports partial updates, but the current Flutter API layer sends
the full editable shape. Both are fine.

Example request:

```json
{
  "title": "Pay electricity + water",
  "note": "",
  "remind_at": "2026-05-21T03:00:00.000000Z",
  "recurrence": "none",
  "lead_times": ["1_hour"]
}
```

Success:

```json
{
  "data": {
    "id": "rem_01jq...",
    "title": "Pay electricity + water",
    "note": null,
    "remind_at": "2026-05-21T03:00:00.000000Z",
    "recurrence": "none",
    "lead_times": ["1_hour"],
    "created_at": "2026-05-14T09:12:00.000000Z",
    "updated_at": "2026-05-14T09:15:00.000000Z"
  }
}
```

Note handling:
- the frontend may send `note: ""`
- the backend may respond with `note: null`
- Belfry should treat `""` and `null` as equivalent empty note values

### Delete reminder

`DELETE /apps/belfry/reminders/{id}`

Success:
- `204 No Content`

## Error handling

The API wrapper should continue surfacing:
- top-level `message`
- otherwise the first Laravel validation error

### Expected statuses

- `401`
  - missing or expired token
  - frontend should clear session and go back to login
- `403`
  - authenticated but no `belfry` app access on app routes
- `404`
  - reminder does not exist or is owned by another user
- `422`
  - validation failure
  - also used by the shared login endpoint for bad credentials or inactive user
- `429`
  - rate limit exceeded
- `0`
  - network / timeout / transport failure in the Flutter client wrapper

### Common UX messages

Recommended frontend copy:
- no app access:
  - `This account does not have access to Belfry.`
- network error:
  - `Can't reach the server. Check your connection.`
- generic request failure:
  - `The request failed. Please try again.`

## Frontend implementation checklist

- keep using `BelfryApi.appKey = 'belfry'`
- keep checking `user.apps` locally after shared login
- do not depend on `user.is_active` being present
- treat login failures as `422`, not `401`
- tolerate logout `200` JSON response
- send and parse reminder timestamps as UTC ISO-8601
- treat `note: ""` and `note: null` as the same empty state
- fetch all reminder pages with `per_page=200`
- sort reminders client-side by computed next occurrence

## Recommended next frontend tasks

- add a short README section pointing to this guide
- add API tests for:
  - login without Belfry access
  - login with object-based `user.apps`
  - logout with `200` response body
  - `note` normalization from `null` to empty UI state
  - paginated reminder fetch combining multiple pages
