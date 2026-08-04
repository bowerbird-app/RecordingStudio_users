# RecordingStudioUsers

`recording_studio_users` is a Rails 8.1 engine that adds Devise authentication integration,
private revisioned Profiles, authorized avatars, identity helpers, User search, and a native
read-only RecordingStudioAdmin Users screen.

## Installation

Add the gem beside the current Recording Studio ecosystem gems, then run:

```sh
bin/rails generate recording_studio_users:install
bin/rails db:migrate
```

The installer is conservative: it skips existing files, reports edits it cannot make safely, and
prints manual next steps. Configure a **persisted system actor** before registration or backfill:

```ruby
RecordingStudioUsers.configure do |config|
  config.user_class_name = "User"
  config.provisioning_actor = ->(user: nil) { SystemActor.find_by(key: "users") }
end
```

An existing User class can be integrated independently:

```sh
bin/rails generate recording_studio_users:integrate_user
bin/rails generate recording_studio_users:migrations
```

The resulting host model declaration is:

```ruby
class User < ApplicationRecord
  include RecordingStudioUsers::User
end
```

Authentication fields remain on the host User. Profile fields and files do not.

## Architecture

The User is a mutable Recording Studio actor, **not** a recordable and not a root. Each User owns
one lightweight `RecordingStudioUsers::UserRoot`, which is a private Recording Studio root. That
root has exactly one active direct self-admin grant and one stable Profile recording.

Profile edits duplicate the current `Profile` snapshot and revise the stable Profile recording.
The avatar logically belongs to the User but is structurally the only permitted active direct
Attachable child of the Profile recording. Replacing an avatar revises the Attachable snapshot
without changing the stable avatar recording.

Private-root `admin` authority is limited to that private root. It never grants workspace,
company, site, or RecordingStudioAdmin authority.

## Provisioning and existing Users

New Users provision through an `after_create` callback; a provisioning failure raises so
registration cannot report success with incomplete topology.

```ruby
RecordingStudioUsers.provision(user, actor: system_actor)
RecordingStudioUsers.provisioned?(user)
RecordingStudioUsers.validate_user_profile!(user)
```

Backfill is restart-safe and reports every success, skip, and failure:

```sh
BATCH_SIZE=250 bin/rails recording_studio_users:backfill_profiles
```

Provisioning serializes on the persisted User row, uses database uniqueness for UserRoot ownership,
uses only `RecordingStudioAccessible.grant_access`, validates the resulting grant, and clears its
execution-local bootstrap context with `ensure`.

## Profiles and avatars

```ruby
RecordingStudioUsers.revise_profile(
  user: user,
  actor: current_user,
  attributes: { display_name: "Ada", locale: "en" }
)

RecordingStudioUsers.upload_avatar(user:, signed_blob_id:, actor:)
RecordingStudioUsers.replace_avatar(user:, signed_blob_id:, actor:)
RecordingStudioUsers.remove_avatar(user:, actor:)
```

Only configured Profile fields are accepted. Authentication and security attributes are rejected.
Avatar services use Attachable's public upload, replacement, and removal services; the engine never
creates dependency-owned records directly or purges blobs directly.
The bundled Profile form uses Active Storage direct uploads, so the host must load Active Storage's
JavaScript. The controller accepts only the resulting signed blob identifier and never creates blobs.

Profile direct attachments are reserved for the avatar. Zero or one active direct attachment is
valid; more than one fails topology validation.

## Privacy and avatar delivery

Identity visibility, email visibility, private Profile access, Profile editing, and stored-avatar
delivery are separate fail-closed policies. Identity visibility does not imply private-Profile
access.

Stored files are returned only through Attachable's authorized preview route and a configured,
trusted variant mapping. Storage URLs, blob keys, signed blob IDs, and provider URLs are never
returned. Attachable routes cannot evaluate arbitrary workspace/comment presentation context, so
stored-avatar delivery must use a context-independent policy the route can verify. Otherwise the
engine falls back to a configured external avatar and then generated initials. It never grants
private-Profile access merely to display an avatar.

## Helpers and components

```erb
<%= recording_studio_user_name(user) %>
<%= recording_studio_user_avatar(user, size: :small) %>
<%= recording_studio_user_identity(user, show_email: false) %>
<%= recording_studio_user_byline(user) %>
```

The engine provides FlatPack-backed avatar, identity, Profile-link, byline, picker-result, auth,
and Profile UI. `show_email: true` still passes the email policy.
Mount the engines with the generator-provided `recording_studio_users` and
`recording_studio_attachable` route aliases so generated Profile and avatar paths retain host
mount prefixes.

## User picker and search

`recording_studio_user_picker` uses `FlatPack::Picker::Component` with remote search. Search requires
an authenticated persisted actor, the configured safe User relation, and an explicit authorizer.
Optional root-scoped searches also require Accessible `view` authority. Wildcards are escaped,
results are bounded and bulk-loaded, invisible identities are omitted, and JSON contains only
presentation fields plus the User ID.

There is no public User directory.

## Bulk loading and performance

```ruby
RecordingStudioUsers.preload_user_information(
  users,
  include: %i[profile avatar],
  context: request_context
)
```

Arrays and relations preserve order. The request/execution-local loader batch-loads UserRoots,
root recordings, Profile recordings and snapshots, avatar recordings and snapshots, and public
Active Storage associations with structured relations. It performs no writes and tolerates
incomplete topology. Context keys isolate authorization-sensitive presentation.

The Admin table triggers this loader only from its first User-backed column after final-page rows
exist, once per context/include set, including async table rendering.

## RecordingStudioAdmin

When `recording_studio_admin` is loaded, the engine registers exactly one site-blast-radius `Users`
section and one read-only `Users` screen with a native summary, created-over-time line chart,
date/group filters, sortable paginated table, authorized identity/avatar/email presentation, and
no mutations or row actions.

Enable `section :users` on the host's configured Admin root. Site access remains controlled by
RecordingStudioAdmin's configured site-access recording and Accessible. The engine never checks
`current_user.admin?`, email allowlists, or special IDs.

## Devise

Default modules are `database_authenticatable`, `registerable`, `recoverable`, `rememberable`, and
`validatable`. The installer supplies FlatPack views for sign-in, registration, password reset,
confirmation, and unlock workflows without replacing existing host views. Confirmable, lockable,
trackable, timeoutable, and OmniAuth remain host choices.

## Public API

See [`docs/API.md`](docs/API.md). All mutation APIs return a normalized result supporting
`success?`, `failure?`, `value`, `error`, and `errors`.

## Extension and no-upstream tradeoffs

The engine composes current public RecordingStudio, Accessible, Attachable, Admin, Active Record,
and Active Storage surfaces. It does not monkey-patch dependency internals, use private creation
contexts, create Access/Attachment/Event records directly, or require upstream changes.

The intentional tradeoffs are:

- all direct Profile attachments are reserved for the singleton avatar;
- stored-avatar visibility must be independently verifiable by Attachable's route;
- Admin page rows preload lazily because Admin has no upstream preload hook;
- unsafe or unavailable authorization context fails closed.

## Security and troubleshooting

See [`docs/SECURITY.md`](docs/SECURITY.md) and
[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

## Development

```sh
bundle exec rake test
bundle exec rake test:all
bundle exec rubocop
```

The dummy app uses PostgreSQL UUIDs and exercises Devise, Profiles, avatars, FlatPack, Accessible,
and Recording Studio integration.
