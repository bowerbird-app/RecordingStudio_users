# Users JSON API (operations)

How a host, person, or AI agent manages **users** over **Recording Studio API**. This surface is authenticated and **admin-only**.

Users are Devise actors, not tree recordables. The gem registers named endpoints with `RecordingStudioApi.register_endpoint` on the host’s `:operations` API. It does **not** gemspec-depend on `recording_studio_api`. If that constant is missing, Users boots with no JSON user routes.

There is no Users `ApiController`. Create with a password calls `RecordingStudioUser.create_user!`. Create without a password calls `RecordingStudioUser.create_unconfirmed_user!` when `otp_enabled?` is true, and returns `422` `password is required` when it is false. Profile writes on update go through `record_profile!`. List uses `RecordingStudioUser.config.user_class.order(created_at: :desc)`, the same order as the Admin users screen, with `page` / `per_page` offset paging. Access is **Accessible** only.

Do not register these routes on the public API (`/recording_studio_api/api/v1`).

## Install (host)

```ruby
gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.6.7"
```

Name the Admin API `:operations` (`default_access :read_only`). Users registers collection and member endpoints on that API and passes each `operations:` registration only through `api: :operations`. Hosts that already define `config.api :operations` (for example featured_in) do not add a second named-API block in this gem.

Enable `:accessible` and `:api_access_point` on the admin root that holds operations keys. Dummy does this on `AdminRoot` and `Workspace`. Allow `RecordingStudioApi::ApiClient` in `access_actor_types`.

## Auth

Bearer access token from OAuth `client_credentials` on the operations token path:

```http
POST /recording_studio_api/apis/operations/oauth/token
Content-Type: application/json

{ "grant_type": "client_credentials", "client_id": "…", "client_secret": "…" }
```

Then:

```http
Authorization: Bearer <access_token>
Accept: application/json
```

The API client’s `AccessGrant.actor` is the Accessible actor. Grant that client on **AdminRoot**.

| Actor | `GET` list / show | `GET` count | `POST` / `PATCH` |
| --- | --- | --- | --- |
| Accessible `:edit` on **AdminRoot** (operations token) | Yes | Yes | Yes |
| Accessible `:view` on **AdminRoot** (operations token) | Yes | Yes | No — `403` |
| Operations token without AdminRoot `:view` | `403` | Yes — existing count endpoint | `403` |
| Workspace-only grant, no AdminRoot | `403` | Rejected with the token | `403` |
| Public token on operations | Rejected | Rejected | Rejected |
| Missing token | `401` | `401` | `401` |

Public `/api/v1/users` is not registered (`404`). There is no `DELETE`.

Users registers GET+POST on `users` and GET+PATCH on `users/:id`. RecordingStudio_api **v0.6.5+** dispatches with `registered_endpoint_registry.match(path:, http_verb:)`, so POST and PATCH reach the right handlers. Pin **v0.6.7** or newer in the host Gemfile. Users does not patch API dispatch.

## Routes

Mount prefix is the host’s API engine path. Dummy uses `/recording_studio_api`. Operations version is `v1`.

| Method | Path | Who | Notes |
| --- | --- | --- | --- |
| `GET` | `/recording_studio_api/apis/operations/v1/users` | AdminRoot `:view` | Offset list (`page`, `per_page`; default 50, max 100). Same order as Admin users. |
| `GET` | `/recording_studio_api/apis/operations/v1/users/:id` | AdminRoot `:view` | One user |
| `GET` | `/recording_studio_api/apis/operations/v1/users/count` | Operations token | Existing endpoint. `{ "count": N }` |
| `POST` | `/recording_studio_api/apis/operations/v1/users` | AdminRoot `:edit` | Password: `create_user!`. No password and one-time codes on: `create_unconfirmed_user!`. No password and one-time codes off: `422` |
| `PATCH` | `/recording_studio_api/apis/operations/v1/users/:id` | AdminRoot `:edit` | Profile fields only (`record_profile!`) |

Send writable fields at the JSON root. Do not wrap them in `attributes`.

## Fields

Serialized keys: `id`, `email`, `first_name`, `last_name`, `time_zone`, `confirmed_at`, `created_at`, `updated_at`, `registered_with`, `identity_providers` (provider names), `additional_profile_attributes` (allowlisted extras only, default `locale`).

Never returned: password digests, password params, reset/confirmation/unlock tokens, OTP secrets, or other credentials.

Writable on create: `email` (required), `password`, `password_confirmation`, `first_name`, `last_name`, `time_zone`, allowlisted extra profile keys. Profile fields are applied only by `create_user!` (password present). `create_unconfirmed_user!` takes `email` only.

Writable on update: `first_name`, `last_name`, `time_zone`, allowlisted extra profile keys. `email`, `password`, and `password_confirmation` are not accepted; sending `email` returns `422` with a clear error.

## Create

With a password, `POST` calls `create_user!` unchanged. `registered_with` stays `password`, the People-root Profile is recorded, and the existing confirmation policy applies. Admin create does not emit `registration.completed`.

Omit `password` (or send blank) while one-time codes are enabled (`RecordingStudioUser.config.otp_enabled?`). `POST` calls `create_unconfirmed_user!`. That method sets `registered_with` to `otp`, skips the confirmation email, and does not call `skip_confirmation!`. The account stays unconfirmed, no Profile is recorded, and Terms are not accepted. Profile fields on that request are ignored.

Omit `password` while one-time codes are off. `POST` returns `422` with `password is required` and creates no user.

## Examples

Count:

```http
GET /recording_studio_api/apis/operations/v1/users/count
Authorization: Bearer <operations_token>
```

```json
{ "count": 12 }
```

List:

```http
GET /recording_studio_api/apis/operations/v1/users?page=1&per_page=50
Authorization: Bearer <operations_token>
```

```json
{
  "records": [
    {
      "id": "…",
      "email": "ada@example.com",
      "first_name": "Ada",
      "last_name": "Lovelace",
      "time_zone": "UTC",
      "confirmed_at": "2026-10-08T00:00:00.000Z",
      "created_at": "2026-10-08T00:00:00.000Z",
      "updated_at": "2026-10-08T00:00:00.000Z",
      "registered_with": "otp",
      "identity_providers": ["google_oauth2"],
      "additional_profile_attributes": { "locale": "en" }
    }
  ],
  "meta": { "page": 1, "per_page": 50, "total_count": 12, "total_pages": 1 }
}
```

Create without a password while one-time codes are on:

```http
POST /recording_studio_api/apis/operations/v1/users
Authorization: Bearer <operations_token>
Content-Type: application/json

{ "email": "new@example.com" }
```

```json
{
  "id": "…",
  "email": "new@example.com",
  "first_name": null,
  "last_name": null,
  "time_zone": null,
  "confirmed_at": null,
  "created_at": "2026-10-08T00:00:00.000Z",
  "updated_at": "2026-10-08T00:00:00.000Z",
  "registered_with": "otp",
  "identity_providers": [],
  "additional_profile_attributes": {}
}
```

Create with a password (same path; `registered_with` is `password`):

```http
POST /recording_studio_api/apis/operations/v1/users
Authorization: Bearer <operations_token>
Content-Type: application/json

{
  "email": "pat@example.com",
  "password": "a-real-password",
  "first_name": "Pat",
  "last_name": "Chable",
  "time_zone": "UTC"
}
```

Update profile:

```http
PATCH /recording_studio_api/apis/operations/v1/users/:id
Authorization: Bearer <operations_token>
Content-Type: application/json

{ "first_name": "Patricia", "time_zone": "UTC", "locale": "fr" }
```

Response is the same user object shape; `email` is unchanged. Do not send `email` — the API returns `422`.

Show:

```http
GET /recording_studio_api/apis/operations/v1/users/:id
Authorization: Bearer <operations_token>
```

Same object shape as create.
