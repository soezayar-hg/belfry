# Belfry — API Contract

The contract between the **Belfry Flutter app** and the **Sozy Gateway**
(`api_gateway/`). The backend module is not built yet; this document is the
spec the gateway must implement and the shape the Flutter client
(`lib/api/belfry_api.dart`, `lib/models/reminder.dart`) already expects.

It is the Belfry counterpart to `expense_app/API_SPEC.json` +
`FRONTEND_API_NEEDS.md`.

---

## Conventions

- **Base URL:** `http://127.0.0.1:8000/api/v1` in development. The client reads
  it from `--dart-define=BELFRY_API_BASE_URL=...`, defaulting to the above.
- **Format:** JSON in, JSON out. The wire format is **snake_case**; the client
  converts to/from camelCase at the `belfry_api.dart` boundary.
- **Auth:** Laravel Sanctum bearer token — `Authorization: Bearer <token>` on
  every call except login.
- **App key:** `belfry`. App-specific routes sit behind three middleware:
  `auth:sanctum`, `throttle:belfry-api`, `app.access:belfry`.
- **Rate limit:** `belfry-api` — 120 requests/minute, keyed by user id (or IP).
- **Timezone:** all instants are stored and transmitted as **UTC** ISO-8601.
  The app displays everything in Asia/Bangkok.
- **IDs:** string ULIDs, prefixed `rem_` (e.g. `rem_01jqabc...`).
- **Collection envelope:** `{ "data": [...], "meta": {...} }`.
  **Single-resource envelope:** `{ "data": {...} }`.

---

## Authentication

These are shared gateway endpoints (not under `/apps/belfry`).

### POST `/auth/login`

Authenticates against the shared gateway account.

**Request**

```json
{
  "email": "user@example.com",
  "password": "secret",
  "device_name": "belfry-macos"
}
```

`device_name` is `belfry-macos` or `belfry-android` (set by the client per
platform).

**Response — `200 OK`**

```json
{
  "token": "12|plaintextSanctumToken...",
  "token_type": "Bearer",
  "user": {
    "id": 1,
    "name": "Sozy",
    "email": "user@example.com",
    "is_admin": false,
    "is_active": true,
    "apps": [
      { "key": "belfry", "name": "Belfry" }
    ]
  }
}
```

**Client behaviour:** after login the client inspects `user.apps`. If no entry
identifies the `belfry` app (either a bare `"belfry"` string or an object with
`key == "belfry"`), the client rejects the login locally with a `403`-style
error — *"This account does not have access to Belfry."* The gateway itself
still returns `200`; Belfry access is enforced per-route by `app.access:belfry`.

**Errors**

| Status | When |
| --- | --- |
| `422` | Missing/invalid fields, or wrong credentials (Laravel validation error). |

### POST `/auth/logout`

Revokes the current token. Requires the bearer token.

**Response — `204 No Content`** (the client also tolerates `200` with an empty
or JSON body).

---

## Reminders

All routes below are prefixed `/apps/belfry` and require
`auth:sanctum` + `throttle:belfry-api` + `app.access:belfry`.

Every query is scoped to the authenticated user. A reminder that does not exist
**or** is not owned by the caller returns `404` (never `403` for ownership).

### The Reminder object

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

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | ULID, prefixed `rem_`. Server-assigned. |
| `title` | string | Required. Max 255 chars. |
| `note` | string \| null | Optional free text. The client sends `""` for "no note"; storing `""` or `null` is both acceptable, the client treats them the same. |
| `remind_at` | string (ISO-8601, UTC) | Required. The **anchor** instant — see *Recurrence model* below. |
| `recurrence` | string enum | One of `none`, `weekly`, `monthly`, `yearly`. Default `none`. |
| `lead_times` | string[] | Subset of `1_min`, `5_min`, `1_hour`, `1_day`, `1_week`, `1_month`. May be empty. Order is not significant. |
| `created_at` | string (ISO-8601, UTC) | Server-assigned. |
| `updated_at` | string (ISO-8601, UTC) | Server-assigned. |

#### Enums

- **`recurrence`** — `none` \| `weekly` \| `monthly` \| `yearly`
- **`lead_times`** entries — `1_min` \| `5_min` \| `1_hour` \| `1_day` \| `1_week` \| `1_month`

#### Recurrence model (important)

`remind_at` is an **immutable anchor**, not a moving "next fire time". The
gateway stores the anchor + the recurrence rule and never advances it. The
**client** derives the next occurrence locally. Consequences for the backend:

- A recurring reminder whose anchor is in the past is still valid and current —
  do **not** roll `remind_at` forward on the server.
- There is no "advance"/"complete" endpoint. Dismissing or snoozing an alarm is
  purely client-side scheduling and never calls the API.
- `recurrence: "none"` means the reminder fires once at `remind_at`.

---

### GET `/apps/belfry/reminders`

Lists the authenticated user's reminders.

**Query parameters**

| Param | Type | Default | Notes |
| --- | --- | --- | --- |
| `page` | int ≥ 1 | `1` | |
| `per_page` | int 1–200 | `50` | The client requests `per_page=200` and walks every page. |

**Response — `200 OK`**

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

Ordering is not relied upon by the client — it sorts locally by computed next
occurrence. Ascending `remind_at` is a reasonable default.

---

### POST `/apps/belfry/reminders`

Creates a reminder.

**Request**

```json
{
  "title": "Pay electricity bill",
  "note": "Account 4471-220",
  "remind_at": "2026-05-20T02:00:00.000000Z",
  "recurrence": "monthly",
  "lead_times": ["1_day", "1_hour"]
}
```

**Validation**

| Field | Rules |
| --- | --- |
| `title` | required, string, max 255 |
| `note` | optional, string, nullable |
| `remind_at` | required, ISO-8601 datetime |
| `recurrence` | optional, one of the `recurrence` enum; default `none` |
| `lead_times` | optional array; each entry one of the `lead_times` enum; default `[]` |

**Response — `201 Created`**

```json
{ "data": { "id": "rem_01jq...", "title": "Pay electricity bill", "...": "..." } }
```

---

### PATCH `/apps/belfry/reminders/{id}`

Updates a reminder. Partial — only the supplied fields change. The client
currently sends the full editable set, but the endpoint should accept any
subset.

**Request** (any subset of)

```json
{
  "title": "Pay electricity + water",
  "note": "",
  "remind_at": "2026-05-21T03:00:00.000000Z",
  "recurrence": "none",
  "lead_times": ["1_hour"]
}
```

Validation mirrors POST, but every field is `sometimes` (optional).

**Response — `200 OK`**

```json
{ "data": { "id": "rem_01jq...", "...": "..." } }
```

**Errors:** `404` if the reminder is unknown or not owned by the caller.

---

### DELETE `/apps/belfry/reminders/{id}`

Deletes a reminder.

**Response — `204 No Content`**

**Errors:** `404` if the reminder is unknown or not owned by the caller.

---

## Error responses

Standard Laravel shapes. The client surfaces `message`, or the first
validation error when `message` is generic.

### `401 Unauthorized` — missing/expired token

```json
{ "message": "Unauthenticated." }
```

The client clears the stored token + cached user and returns to the login
screen.

### `403 Forbidden` — authenticated but lacks `belfry` access

```json
{ "message": "You do not have access to this app." }
```

Returned by `app.access:belfry` on any `/apps/belfry/*` route.

### `404 Not Found` — unknown or non-owned reminder

```json
{ "message": "Not found." }
```

### `422 Unprocessable Entity` — validation failure

```json
{
  "message": "The title field is required.",
  "errors": {
    "title": ["The title field is required."],
    "lead_times.0": ["The selected lead_times.0 is invalid."]
  }
}
```

### `429 Too Many Requests` — rate limit exceeded

Returned when the `belfry-api` limiter (120/min) trips.

---

## Endpoint summary

| Method | Path | Auth | Body | Success |
| --- | --- | --- | --- | --- |
| POST | `/auth/login` | — | `email`, `password`, `device_name` | `200` `{token, token_type, user}` |
| POST | `/auth/logout` | bearer | — | `204` |
| GET | `/apps/belfry/reminders` | bearer + `app.access:belfry` | — (query: `page`, `per_page`) | `200` `{data[], meta}` |
| POST | `/apps/belfry/reminders` | bearer + `app.access:belfry` | reminder fields | `201` `{data}` |
| PATCH | `/apps/belfry/reminders/{id}` | bearer + `app.access:belfry` | partial reminder fields | `200` `{data}` |
| DELETE | `/apps/belfry/reminders/{id}` | bearer + `app.access:belfry` | — | `204` |

---

## Notes for the backend implementer

- Seed the app: `apps` row `key => belfry`, `name => Belfry`. Access is granted
  per-user from the admin panel — there is no public registration.
- Table `belfry_reminders`: `id` (string PK), `user_id` (FK, cascade on user
  delete), `title`, `note` (nullable text), `remind_at` (timestamp),
  `recurrence` (string), `lead_times` (json), timestamps. Index
  `(user_id, remind_at)`.
- Hand-serialise responses in snake_case, consistent with the Todo and Tally
  modules — `remind_at`, `created_at`, `updated_at` as ISO-8601 UTC strings.
- Register a `BelfryAppReportGenerator` (`appKey() => belfry`) in
  `AppReportRegistry` so the admin export page covers Belfry.
- Full design rationale lives in
  `docs/superpowers/specs/2026-05-14-belfry-design.md`.
