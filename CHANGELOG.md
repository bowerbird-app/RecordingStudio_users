# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Login codes are available to **any** confirmed, active account, including password accounts. `registered_with` records how an account was created rather than restricting how it signs in. Registration codes are still OTP-account only, and OTP accounts still cannot sign in with a password.
- Renamed the users column `authentication_method` to `registered_with`. Predicates are `registered_with_otp?` and `registered_with_password?`. Hosts that already migrated should generate and run `rename_authentication_method_to_registered_with`; new hosts get `add_registered_with_to_users` instead of `add_authentication_method_to_users`.
- Login notifications open a recipient-only code page while the challenge is active. The plaintext code remains absent from the notification row; used, revoked, expired, and over-attempted challenges show a request-new-code state.
- Dummy eagerly registers Notifications and Push Stimulus controllers so their loaders do not try to resolve Flatpack controllers inside notification namespaces.
- Dummy vendors `recording_studio_notifications` `0.3.0`, `recording_studio_notifications_email` `0.3.0`, and `recording_studio_notifications_push` `0.2.0` from their merged `main` branches.
- Dummy mounts the notifications inbox at `/notifications`, email as a channel (no screens), and push devices at `/notifications/push`. Debug chrome adds inbox, settings, and devices links plus the async notification menu.
- Dummy development mail uses Letter Opener Web. The debug sidebar adds a **Letters** link to `/letter_opener`.
- Dummy seeds a confirmed `otp@admin.com` account so email-code sign-in is testable. Password accounts do not receive login codes.

### Upgrade notes
- Hosts that already added `users.authentication_method` should run `rails generate recording_studio_user:migrations` and migrate `rename_authentication_method_to_registered_with`. Delete `*_add_authentication_method_to_users.rb` if that file has not run yet. Verify with: `User.column_names.include?("registered_with")` and `!User.column_names.include?("authentication_method")`.

## [0.7.0] - 2026-09-01

### Added
- Optional email OTP registration and login (`config.otp_enabled`, default `false`). Password and OTP are separate registration choices; `authentication_method` is persisted as `password` or `otp`.
- `RecordingStudioUser.create_unconfirmed_user!`, `issue_otp!`, `verify_otp!`, `complete_registration!`, and `OtpDeliveryPayload` for secure notification delivery.
- Migration generator templates for `authentication_method`, Devise confirmable columns, and `recording_studio_user_otp_challenges`.
- Auth controllers and Flatpack views for password/OTP registration and login when OTP is enabled.
- `recording_studio_user:cleanup_otp` task for expired challenges and abandoned unconfirmed OTP users.

### Changed
- When `otp_enabled`, the engine idempotently enables Devise `:confirmable` and registers `registration_otp` / `login_otp` notification types with delivery-payload resolvers.
- Password registration calls `skip_confirmation!` when `password_registration_confirmation` is `:existing_policy`.

### Upgrade notes
- Hosts that relied on password accounts being refused login codes must set `otp_login_enabled = false` to keep that behaviour. Verify with: request a code for a confirmed password account and assert `RecordingStudioUser::OtpChallenge.where(user: user, purpose: "login")` is empty.
- Requires `recording_studio_notifications` `>= 0.3.0` and `recording_studio_notifications_email` when OTP is enabled. Optional push uses `recording_studio_notifications_push` `>= 0.2.0` for login codes.
- Run `rails generate recording_studio_user:migrations` and migrate before setting `config.otp_enabled = true`.
- Map host Devise routes to `recording_studio_user/auth/*` controllers (see dummy `config/routes.rb`). Keep OmniAuth callbacks on `recording_studio_user/omniauth_callbacks`.

## [0.6.2] - 2026-08-31

### Added
- Devise OmniAuth sign-in for Google, Microsoft, Apple, LinkedIn, and Instagram. Hosts leave `omniauth_providers` empty so buttons follow Rails credentials under `omniauth:`; an empty credentials hash leaves email/password sign-in unchanged.
- Provider identities and an owner-only **Sign-in methods** page for connecting and disconnecting configured providers.
- Automatic identity linking to an existing User with the same normalized email. Unknown emails create a User and Profile only when `omniauth_create_account` is enabled.
- Credential-first, environment-variable fallback examples for every supported provider in the generated initializer. OAuth tokens are not stored.

### Changed
- Continue, Connect, and Disconnect actions submit real CSRF-protected forms so they work in Turbo-only hosts without rails-ujs.
- The identities migration uses a new guarded migration version. It restores the table for hosts that followed the 0.6.1 drop instruction and repairs indexes and the foreign key on retained 0.6.0 tables.
- Dummy home and `/docs/*` pages again use `flat_pack_sidebar` (Install, Config, diagnostics, Sign out, Root Switchable). Profile and other product surfaces stay on `recording_studio/default_layout`.
- Continue-with buttons follow Rails credentials under `omniauth:`. An empty `omniauth_providers` hash reads those keys; blank or commented credential entries stay hidden. Dummy development credentials keep live Google secrets and commented examples for Microsoft, Apple, LinkedIn, and Instagram.
- Sign-in methods lists only identities whose provider is still configured, and disconnect no longer counts an identity for a dropped provider as a remaining sign-in method. An identity for an unconfigured provider cannot sign anyone in, because no strategy or callback route exists for it.
- Dummy never enables OmniAuth test mode or `OMNIAUTH_TEST_MODE`. Dummy tests set `OmniAuth.config.test_mode` in `test/test_helper.rb` only.
- Dummy README, gem README, and dummy Config docs point at the BowerBird Dev GCP **RecordingStudioUsers** OAuth client used by `test/dummy`.

### Upgrade notes
- Bump to `0.6.2`, run `bin/rails generate recording_studio_user:migrations`, then `bin/rails db:migrate`.
- If a provider was configured in `0.6.0` and is no longer in credentials, its identity rows are now hidden and inert. Delete them with `bin/rails recording_studio_user:prune_unconfigured_identities`.
- Add provider secrets under `omniauth:` in Rails credentials. Leave `config.omniauth_providers` empty so buttons appear from those keys. Set `omniauth_create_account = false` to reject provider emails that do not match an existing User.
- Route `devise_for :users` callbacks to `recording_studio_user/omniauth_callbacks`.
- Render `recording_studio_user/omniauth/continue_with_providers` in host Devise login and sign-up views. Link the engine's **Sign-in methods** page from the profile if the host overrides the supplied profile view.
- First login requires a provider email. Instagram may not provide one; Apple may return one only on first consent or use a private relay. Connecting from a signed-in profile does not require an email.

## [0.6.1] - 2026-08-31

### Removed
- OmniAuth multi-provider sign-in added in `0.6.0` (Google, Microsoft, Apple, LinkedIn, Instagram). Removes identities table support, Sign-in methods page, OAuth callbacks, `continue_with_providers` partial, and related configuration (`omniauth_providers`, `omniauth_create_account`, `login_title`). Host Devise email/password sign-in is unchanged.

### Changed
- `require_password_confirmation` default restored to `true` (was `false` in `0.6.0`).
- Flatpack pin restored to `~> 0.1.141` (was `~> 0.1.143` in `0.6.0`).

### Upgrade notes
- Bump to `0.6.1`. No new migrations — the gem no longer ships or references `recording_studio_user_identities`.
- Remove OmniAuth strategy gems (`omniauth`, `omniauth-rails_csrf_protection`, and provider gems) from the host Gemfile if you added them for `0.6.0`.
- Remove `config.omniauth_providers`, `config.omniauth_create_account`, and `config.login_title` from `config/initializers/recording_studio_user.rb`.
- Revert `devise_for :users` OmniAuth callback routing (`controllers: { omniauth_callbacks: … }`) and remove `render "recording_studio_user/omniauth/continue_with_providers"` from host Devise login/sign-up views.
- Drop the identities table if you no longer need OAuth account links: `bin/rails db:drop_table recording_studio_user_identities` (or a host migration). The table is inert once OmniAuth config is removed.
- Users who signed in only via OAuth (no password) cannot sign in with email/password until a host admin sets a password or the feature returns in a later release.

## [0.6.0] - 2026-08-29

### Added
- OmniAuth sign-in for **Google, Microsoft, Apple, LinkedIn, and Instagram**. Users owns OmniAuth config, identities, callbacks, find-or-create, Sign-in methods, and the Flatpack `continue_with_providers` partial. Host keeps Devise `User` and `devise_for :users`.
- `RecordingStudioUser::Configuration#omniauth_providers` (default `{}`) and `#omniauth_create_account` (default `true`). When providers is empty, login looks as today. Dummy enables all five with OmniAuth test-mode mocks (or `ENV`).
- Strategy gems: `omniauth-google-oauth2`, `omniauth-microsoft_graph`, `omniauth-apple`, `omniauth-linkedin-openid`, `omniauth-instagram-api`, plus `omniauth` / `omniauth-rails_csrf_protection`. Providers register by config key — not a Google-only branch.
- `recording_studio_user_identities` table and `RecordingStudioUser::Identity` (provider + uid unique; one User, many identities). Identities are not recordables and are not in the People tree.
- Find-or-create used by the callback: Identity by provider+uid → else User by email (link Identity) → else create via `Directory.create_user!` / `record_profile!` when `omniauth_create_account` → else fail closed. Connect while signed in attaches to the current User (no invented email); uid already on another User is rejected. Disconnect deletes that Identity and refuses if it is the only sign-in method and the user has no password.
- Owner-only **Sign-in methods** page at `profile/sign-in-methods` (Flatpack Card + List with configured provider logo). Connected rows use Disconnect; each configured but unlinked provider gets the same row with Connect (secondary, sm). Edit Profile stays photo + name + timezone only (no Sign-in methods link). Avatar uses profile name for initials / alt — never the word "Avatar". My Profile show stays read-only with **Edit** and **Sign-in methods** actions (no `page_nav_back_*`; core Flatpack PageNav still paints history.back — see notes).
- Optional `omniauth_providers[:provider][:logo]` (URL or inline SVG). Gem ships default SVGs for all five. Flatpack List has no first-class image-URL lead; SVG uses `icon:`, image URLs use `leading:` with an `<img>`. `:logo` is stripped before Devise strategy registration.
- **Email caveats:** first login without email fails closed (`MissingEmailError`). Instagram often has no email; Apple may send it only once / as a relay. Connect-from-profile still works with a blank `Identity.email`.
- `RecordingStudioUser::Configuration#login_title` (default `"Welcome back"`) for the host Devise login heading. Blank values fall back to the default. Install generator comments the option.

### Changed
- Host `devise_for` must route OmniAuth callbacks to Users: `controllers: { omniauth_callbacks: "recording_studio_user/omniauth_callbacks" }`. ProfiledUser adds `:omniauthable` when providers are present and sets `password_required?` false while an identity exists.
- Migrations generator also copies the identities table.
- Dummy Devise login and sign-up use ordinary Tailwind viewport centering (`min-h-dvh flex items-center justify-center`, inner `max-w-sm w-full`) without a Card: centered title → fields → primary button → centered cross-link → `Divider` (`label: "Or"`) → full-width secondary Continue-with buttons (provider logo via `icon:`). Login omits Remember me and the seed credential Badge. `require_password_confirmation` defaults to `false` (dummy signup has no confirm field; hosts may set `true`). Requires Flatpack `~> 0.1.143` (tagged `v0.1.143`, includes Divider). Button `icon:` SVG logos use a small engine shim until Flatpack Button mirrors List::Item.

### Upgrade notes
- Bump to `0.6.0`. Requires Flatpack `~> 0.1.143` (git tag `v0.1.143`).
- Run `bin/rails generate recording_studio_user:migrations` and `bin/rails db:migrate` for `recording_studio_user_identities`.
- Set `config.omniauth_providers` (per-provider `client_id` / `client_secret` from credentials or ENV; optional `logo` and strategy options such as Apple `team_id` / `key_id` / `pem`) and `config.omniauth_create_account` as needed. Point `devise_for :users` OmniAuth callbacks at `recording_studio_user/omniauth_callbacks`.
- Optional `config.login_title` (default `"Welcome back"`) for the Devise login heading.
- `config.require_password_confirmation` now defaults to `false`. Set `true` if the host still wants a confirmation field on Devise sign-up.
- Mount Sign-in methods at the engine profile route (`…/profile/sign-in-methods`). Link it from My Profile; keep Connect/Disconnect off show and off Edit.
- Render `recording_studio_user/omniauth/continue_with_providers` on host Devise login/sign-up when any provider is configured (replaces the old Google-only partial name). The partial includes the labeled Or divider and one Continue button per provider. Secrets stay out of the repo.
- OAuth tokens are not stored. Login needs provider, uid, and email (except Connect-while-signed-in, which tolerates a blank email).

**Note:** `0.6.1` removes everything above. Do not upgrade to `0.6.0` — go straight to `0.6.1` or later.

## [0.5.1] - 2026-08-29

### Changed
- Dummy and development Gemfiles pin Flatpack `v0.1.141` (annotated tag `31ea491672030525cd0fd0b300e0ae7041b65981`, commit `c50fee8a4b1bbd73d1122d6d0b8fff5873b26220`). The gemspec requires `flat_pack ~> 0.1.141`. FormField DRY from Flatpack 0.1.140 lets Timezone Select and password TextInputs share one chrome/height; this release is the pin only — no Users restyle of Select or TextInput.

### Upgrade notes
- Require Flatpack `~> 0.1.141` (pin git tag `v0.1.141`). No host view or config changes for this bump.

## [0.5.0] - 2026-08-22

### Added
- Enabled Recording Studio Attachable on **Profile** with `include RecordingStudio::Capabilities::Attachable.to(allowed_content_types: ["image/*"], enabled_attachment_kinds: %i[image], max_file_count: 1)`. People stays without Attachable. `max_file_count` is a per-upload batch limit, not a lifetime cap; the product still shows one image.
- Public helpers `profile_image_recording_for`, `attach_profile_image!`, and `replace_profile_image!`. The image is an Attachable child of the Profile recording (`import_attachment`), not a parallel table.
- Profile **show** renders one Flatpack elevated Card: Avatar (image or person-icon fallback) above unlabeled name, email, and time zone in one column on every width. **Edit** hosts a `profile-photo` Turbo frame with Flatpack Avatar (`attachment_preview_url`, `size: :"2xl"`, `shape: :circle`) plus Attachable `render_attachment_file_button` for Add/Change. These screens are not a gallery or library.
- Dummy mounts `RecordingStudioAttachable::Engine`, runs Active Storage plus Attachable migrations, wires direct uploads, and seeds Avery Admin (`admin@admin.com`) with a real image on their Profile recording. `doc/review/profile-edit-upload.mp4` records a throwaway empty Edit Profile using the camera slot — the Avatar updates on the same URL, not via seeded stills.

### Changed
- Profile PageNav right slot is empty. Profile is owner-only: Accessible still records the first owner with `bootstrap_owner_access!`, but show/edit no longer render `recording_access_management_link` or any grant/invite control.
- Dummy overrides Attachable's attachment show so only core `recording_studio/default_layout` PageNav renders if that leftover URL is opened. Profile screens do not link there.
- Dummy `recording_studio/_default_layout_head` sets `html data-theme="rounded"` so Flatpack `--button-primary-*` aliases inherit charcoal. Core's body attribute alone leaves `:root` primary blue.
- Dummy Devise sign up (`/users/sign_up`) uses Flatpack `EmailInput`, `PasswordInput` (password + confirmation), and a primary **Sign up** button on `layouts/application`. It is still Devise registerable, not a Users product registration flow.
- `require_password_confirmation` (default `true`) hides the Devise confirmation field and does not require the param when the host turns it off.
- Empty Profile photos use Flatpack Avatar's person-icon fallback (no name/initials). Edit's Add/Change control persists through Attachable import / `replace_attachment_file` and stays on Edit Profile. Edit hosts a `profile-photo` Turbo frame; Attachable only supplies `attachment_preview_url` and `render_attachment_file_button`. An `mb-8` wrapper around the frame keeps the gap under the whole slot.
- Profile show puts **Edit** in the PageTitle actions slot (not in the card) and drops the subtitle. A Flatpack Grid `cols: 2` wraps the Card only (desktop width cap). Inside the card, Avatar sits above unlabeled name, email, and time zone — one column on desktop and phone. No inner Grid and no flex row. No city field. Edit wraps the Attachable photo slot, stacked fields, and Update / Cancel in a Flatpack Grid `cols: 2` so the form occupies one cell (width constraint). Fields stay full-width rows — not two columns of first/last name. Update profile and Cancel are two separate Flatpack buttons, not a ButtonGroup. Edit keeps the plain subtitle: "Change your name, time zone, or photo."
- Dummy and development Gemfiles pin `recording_studio_attachable` to published tag `v0.5.0` (annotated tag `542777b2557ea235050fd4f42753653df90fe957`, commit `76c3b234e392df823013a36f2d8d1a6b57c951f0`) so `render_attachment_file_button` owns Add/Change text buttons. The gemspec requires `~> 0.5.0`.
- Dummy and development Gemfiles pin Flatpack `v0.1.135` (annotated tag `534ce32b29d0d1666c24d04e75485ddd57fa4e2f`, commit `e9318c39498e14d13ad2bee69ce945bb62081402`). The gemspec requires `flat_pack ~> 0.1.135` so Edit Profile can pass Avatar `size: :"2xl"` (`h-24 w-24`, 96px). Show stays `:xl`.

### Upgrade notes
- Enable Attachable on Profile only, using the `.to` mixin and the image-only options above. Do not enable it on People.
- Require RecordingStudioAttachable `~> 0.5.0` (pin git tag `v0.5.0`). Run `bin/rails generate recording_studio_attachable:install`, `bin/rails generate recording_studio_attachable:migrations`, and `bin/rails active_storage:install` if those are missing. Mount the engine and keep `@rails/activestorage` plus `ActiveStorage.start()` as the Attachable README describes.
- Remove `recording_access_management_link` (and any Access control) from Profile PageNav. First-owner bootstrap stays; do not add invite/grant UI on Profile.
- Use `attach_profile_image!` or `recording.import_attachment` to place one image under the Profile recording. On Edit Profile host a `profile-photo` Turbo frame with Flatpack Avatar (`src: attachment_preview_url(recording, variant: :square_med)`, `size: :"2xl"`, `shape: :circle`) and `render_attachment_file_button(recording, return_to: edit_profile_path)`. Wrap the frame in `mb-8`. Do not call `render_parent_attachment` or `render_attachment_image_slot`. Require Flatpack `~> 0.1.135` (this branch pins tag `v0.1.135`). Attachable owns the Add/Change labels — do not invent Users button copy. On My Profile wrap one elevated Card in a Grid `cols: 2` width cap and stack Avatar above unlabeled name, email, and time zone. Do not put Avatar and text in that Grid. Do not compose a Users-owned photo form or link replace to `attachments#show`. Show can keep `:xl`.
- If Attachable uses core `recording_studio/default_layout`, you can still override the leftover attachment show view so it does not render a second PageNav. Profile screens do not navigate there.
- Hosts that use core `recording_studio/default_layout` should add `app/views/recording_studio/_default_layout_head.html.erb` that sets `document.documentElement.setAttribute("data-theme", "rounded")`. Core puts the named theme on `body`; Flatpack `--button-primary-*` aliases live on `:root` and otherwise stay the default blue. Do not copy the layout or invent a host theme.

## [0.4.0] - 2026-08-21

### Changed
- Profile show no longer renders `notice` itself. Core `recording_studio/default_layout` already shows `flash[:notice]` as a FlatPack alert, so Devise sign-in no longer flashes twice.
- Dummy host chrome uses `RecordingStudio::UsesDefaultLayout` (Devise keeps `application`). Profile show/edit are PageNav back/close only — no sidebar, Sign out, or Root Switchable. `RecordingStudioUser.config.layout` is `recording_studio/default_layout`. Dummy does not fork that layout; rounded comes from core's `body data-theme` (default `"rounded"`) and `html data-theme="rounded"` on Devise `application.html.erb`.
- Profile PageNav right slot uses Accessible's public `recording_access_management_link`. Dummy mounts `RecordingStudioAccessible::Engine` and ships the `--link-helper` helper.
- First-owner access on a new Profile recording uses `RecordingStudioAccessible.bootstrap_owner_access!` (role `:admin`). Later membership still uses `grant_access`.
- Removed the Users paper-over that swapped `access_management_authorizer` / retried `grant_first_owner` when the Profile had no admin yet.
- Pinned `recording_studio_accessible` to `~> 0.7` (tag `v0.7.0`). Accessible 0.7.0 allows bootstrap on an accessible child under a shared root (Profile under People).

### Upgrade notes
- If a host profile view still renders `notice` / `flash[:notice]`, remove that alert so only the layout flash remains.
- For UsesDefaultLayout chrome, include `RecordingStudio::UsesDefaultLayout` on the host controller (Devise can keep `application`) and set `RecordingStudioUser.config.layout = "recording_studio/default_layout"`. Do not copy core's default layout into the host.
- Mount Accessible and run `bin/rails generate recording_studio_accessible:access_management --link-helper` so profile screens can call `recording_access_management_link`.
- Upgrade RecordingStudioAccessible to `0.7.0` before installing this gem. 0.6.1 still rejects Profile bootstrap with `Recording must be a root recording`.
- Call `create_user!` / `record_profile!` for signup and backfill. Those helpers bootstrap the Profile recording only — never People.
- Replace any host use of `ProfileAccess.ensure_owner_access!` or an `access_management_authorizer` mutex with `bootstrap_owner_access!` on the Profile recording, then `grant_access` for later members.
- Do not bootstrap People. Do not bootstrap owned-root children. Do not enable Accessible on People.

## [0.3.0] - 2026-08-21

### Added
- Enabled Recording Studio Accessible on **Profile** with `RecordingStudio.enable_capability(:accessible, on: self)`. People stays a shared root without Accessible.
- `create_user!` and `record_profile!` grant the user `:admin` on their Profile recording through `RecordingStudioAccessible.grant_access`.
- Profile show, edit, and update authorize with `RecordingStudioAccessible.authorized?` on that Profile recording. The leftover 0.1.5 screens now read and revise Profile snapshot fields so those requests do not 500 on missing User columns.

### Changed
- Removed the Devise `current_user`-only profile ACL. Authentication is still Devise; authorization is Accessible.
- Users administration is unchanged: Admin root + Accessible, not `user.admin?`.
- Updated the development and dummy app RecordingStudioAdmin pin to 2.0.1. Direct browser visits to admin frame endpoints now redirect to their styled parent screen while Turbo Frame requests still return fragments.

### Upgrade notes
- Register `RecordingStudioUser::Profile` (and People) in `config.recordable_types`. Keep `access_actor_types` configured so User can receive grants.
- Create or backfill profiles with `create_user!` / `record_profile!` so each user receives an Accessible grant on their Profile recording. A Profile row without a grant is forbidden on the mounted profile routes.
- Do not enable Accessible on People. Do not grant on the shared People root.
- Existing hosts that created Profile recordings in 0.2.0 without grants should call `record_profile!` (or `ProfileAccess.ensure_owner_access!`) once per user.
- Upgrade RecordingStudioAdmin to 2.0.1 or newer so opening `/screens/:key/chart`, `/table`, `/table_count`, and widget frame URLs as pages returns the styled parent screen.

## [0.2.0] - 2026-08-21

### Breaking
- User is now the Devise actor only. Host User no longer stores `first_name`, `last_name`, `time_zone`, or `additional_profile_attributes`.
- This gem now owns **People** (`root: true`, `shared: true`, label `"People"`) and **Profile** as a child under People, with `user_id` on the Profile snapshot.
- `display_name_for` reads the current Profile snapshot, not User name columns.
- Signup-shaped writes go through `RecordingStudioUser.create_user!` / `record_profile!`, which call `people_root.record(Profile)` and `revise`. Do not insert `Recording` or `Event` rows directly.

### Added
- People and Profile recordable models, engine migrations, and `recording_studio_user:migrations`.
- Dummy pins for RecordingStudio `v4.2.0`, Accessible `v0.6.1`, Attachable `0.4.0`, and FlatPack `v0.1.133`. Accessible and Attachable are bundled but not enabled on People or Profile. Dummy registers `RecordingStudioAttachable::Attachment` so declaration validation can boot.

### Changed
- Gemspec now requires `recording_studio ~> 4.2` plus `recording_studio_accessible` and `recording_studio_attachable`. Dropped unused `pagy`.
- Users admin table no longer reads a User time zone column.

### Upgrade notes
- Remove `first_name`, `last_name`, `time_zone`, and `additional_profile_attributes` from the host User table and model. Those fields live on Profile.
- Register `RecordingStudioUser::People` and `RecordingStudioUser::Profile` in `config.recordable_types`.
- Run `bin/rails generate recording_studio_user:migrations` and `db:migrate`.
- Create users with `RecordingStudioUser.create_user!(email:, password:, first_name:, last_name:, time_zone:)` or `User.create!` then `people_root.record(Profile)`.
- Accessible grants and Attachable avatars are not enabled in 0.2.0. Do not add a custom ACL while waiting for those slices.

## [0.1.5] - 2026-08-21

### Changed
- Restored the users-admin capability to a read-only report: the gem no longer ships user show/edit routes or role-gated admin profile editing.
- Pointed the users section at the RecordingStudioAdmin screen path so the users report is enabled, and kept the total-users widget on the mounted `recording_studio_users.admin_path` helper.
- Used the dummy host sidebar layout for profile pages and the mounted profile helper for **My profile**.
- Preserved the original Devise users migration and kept profile columns in a host-owned additive migration.
- Installer now also injects resolved relative Tailwind `@source` paths for this engine and FlatPack when those locations can be determined.
- Dummy app pins FlatPack Stimulus controllers under `controllers/flat_pack`, generates gem Tailwind sources before each CSS build, and watches CSS without requiring watchman.
- Bumped development and dummy pins to RecordingStudio `4.2.0`, Accessible `0.6.1`, Root Switchable `0.5.0`, FlatPack `0.1.133`, and RecordingStudioAdmin `2.0.0`.
- Dummy sidebar items and buttons use FlatPack 0.1.133's `text:` / `href:` arguments.
- Dummy seeds and integration tests grant first-owner access with `RecordingStudioAccessible.bootstrap_owner_access!` instead of `AccessCreationContext.allow`.

### Upgrade notes
- Remove any host links or tests that called gem-owned admin user show/edit/update routes. Users administration is a read-only report.
- If the users report screen does not appear, make sure the `:users` section links with `context.admin_screen_path("recording_studio_users")` so RecordingStudioAdmin enables that screen.
- Rebuild host Tailwind CSS after install (`bin/rails tailwindcss:build`). If FlatPack layout utilities are missing, add an `@source` that points at the installed `flat_pack` `app/components` directory.
- Pin FlatPack controllers with `under: "controllers/flat_pack"` so Stimulus can load `flat-pack--*` controllers.
- Upgrade RecordingStudio to `~> 4.1`, Accessible to `~> 0.6` (prefer `0.6.1` for `bootstrap_owner_access!`), and RecordingStudioAdmin to `~> 2.0` before installing this gem. Run the RecordingStudio harden-indexes migration (`rails g recording_studio:migrations` or the equivalent host migration) and `db:migrate`.
- Use `RecordingStudioAccessible.bootstrap_owner_access!(recording:, actor:)` for the first `:admin` grant on an empty owned root. Use `grant_access` for later invites.
- FlatPack `0.1.133` buttons take `href:` (not `url:`) and sidebar items take `text:` (not `label:`).

## [0.1.4] - 2026-08-14

### Added
- Added a shared RecordingStudioAdmin users screen with sitewide totals, creation-over-time reporting, filtering, user details, and protected table actions.
- Added dummy-app workspace and Admin-root fixtures demonstrating RecordingStudioAccessible access filtering.

### Changed
- Updated the profile page layout and added root-aware profile and users-administration navigation to the dummy app.
- Restricted user profile edits to actors with `:admin` access while retaining report and detail access for actors with `:view` access.
- Moved users administration rendering and navigation to the configured RecordingStudioAdmin surface.

### Security
- Added authorization and site blast-radius checks around users reporting and user-table actions.

## [0.1.3] - 2026-08-14

### Changed
- Released RecordingStudioUser version `0.1.3`.

## [0.1.2] - 2026-07-21

### Changed
- Bumped the dummy app FlatPack dependency from `v0.1.33` to `v0.1.129`

## [0.1.1] - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.0] - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_users/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.5.1
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.2.0
[0.1.5]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.5
[0.1.4]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.4
[0.1.3]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.3
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.1.0
