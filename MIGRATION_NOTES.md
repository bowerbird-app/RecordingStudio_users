# Migration Notes - Private Gems to Public Gems

## Completed Changes

1. Removed repository access entries from `.devcontainer/devcontainer.json`.
2. Updated `docs/gem_template/CODESPACES.md` and `docs/gem_template/PRIVATE_GEMS.md` for public dependencies.
3. Replaced MakeupArtist with FlatPack in the dummy app dependency, views, layouts, and Tailwind sources.
4. Pinned the dummy app to FlatPack `v0.1.133` in `test/dummy/Gemfile` and its lockfile.
5. Regenerated the dummy app bundle and completed the FlatPack installation work.

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Public RubyGems and GitHub access for dependency installation
- No private gem credentials for the template dependencies

## Verification

Install both bundles and run the complete gem and dummy app test path:

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Run the dummy app from its directory for browser verification:

```bash
cd test/dummy
bin/dev
```

Use the [FlatPack repository](https://github.com/bowerbird-app/flatpack) and the live FlatPack demo linked from the top-level README for current component documentation.

## Email OTP authentication

### Dependencies

- `recording_studio_notifications` 0.3+
- `recording_studio_notifications_email` 0.3+ (required for email delivery)
- `recording_studio_notifications_push` 0.2+ (optional; login OTP push channel)

### Migrations

Run the migrations generator after upgrading:

```bash
bin/rails generate recording_studio_user:migrations
bin/rails db:migrate
```

New templates:

1. **`add_registered_with_to_users`** — adds `registered_with` (`password` or `otp`) with a check constraint. Backfills existing rows to `password`. If `authentication_method` is still present, it is renamed instead.
2. **`add_devise_confirmable_to_users`** — adds Devise confirmable columns. Backfills `confirmed_at` for existing users so password accounts stay signed-in.
3. **`create_recording_studio_user_otp_challenges`** — stores hashed OTP codes, expiry, attempts, and encrypted delivery ciphertext.

Install and migrate the notifications gems before enabling OTP.

### Enable after migrate

```ruby
RecordingStudioUser.configure do |config|
  config.otp_enabled = true
  config.otp_registration_enabled = true
  config.otp_login_enabled = true
  config.registration_authentication_methods = %i[password otp]
end
```

`otp_enabled` must stay `false` until migrations have run; the engine validates schema on boot when OTP is on.

### Route mapping

Mount password and OTP auth with the host helper (dummy and new installs use this):

```ruby
devise_for :users,
           skip: %i[sessions registrations passwords],
           controllers: { omniauth_callbacks: "recording_studio_user/omniauth_callbacks" }
recording_studio_user_auth_for :users
```

| Path | Purpose |
| --- | --- |
| `GET /users/sign_in` | Email-only login entry (Continue with email) |
| `POST /users/sign_in` | Continue: store email, then password or OTP verify per `primary_login_type` |
| `GET/POST /users/sign_in/password` | Password screen / submit (`user_session`) |
| `GET /users/sign_up` | Email-only registration entry |
| `POST /users/sign_up` | Continue: store email, then password or OTP verify per `primary_login_type` |
| `GET/POST /users/sign_up/password` | Password screen / submit (`user_registration`) |
| `GET/POST /users/sign_up/otp` | Start OTP registration (deep link) |
| `GET/POST /users/sign_up/verify` | Enter registration code |
| `POST /users/sign_up/resend` | Resend registration code |
| `GET/POST /users/sign_in/otp` | Start login OTP (deep link) |
| `GET/POST /users/sign_in/verify` | Enter login code |
| `POST /users/sign_in/resend` | Resend login code |

`primary_login_type` defaults to `:email` (password on the second screen). Set `:otp` only when OTP is fully enabled. Password screens work with OTP off. Direct OTP paths return not found while `otp_enabled` is false.
