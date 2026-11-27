# RecordingStudioUser

`RecordingStudioUser` is an isolated, mountable Rails engine. It keeps the host `User` as a Devise actor and owns **People** plus **Profile** as Recording Studio recordables.

- **User** stays the actor only: Devise, uuid, email, password. It is not a recordable and not a root.
- **People** is this gem's shared root (`label: "People"`, `root: true`, `shared: true`), the same idea as core's `MessagesRoot`. Workspace remains the host's owned bucket.
- **Profile** is the only child under People. One current profile per user, with `user_id` on the snapshot. User is not in the tree.
- One profile image sits under the Profile recording as an Attachable child. Not a gallery. Not a parallel table.

Accessible grants live on **Profile** recordings so the owner can show and edit. Profile screens do not invite other actors. This gem still ships the mounted profile routes and the read-only RecordingStudioAdmin users report.

## Installation

Add the engine to the host application's Gemfile:

```ruby
gem "recording_studio_user"
```

`recording_studio` (>= 6.1.0), `recording_studio_accessible` (~> 0.11), `recording_studio_attachable` (~> 0.7), `recording_studio_admin` (~> 2.0), `recording_studio_metrics` (>= 0.3, < 1.0), `recording_studio_cache` (>= 0.5, < 1), `flat_pack` (>= 0.1.328), `view_component` (>= 4.14, < 5), `devise`, the supported OmniAuth strategies, and `omniauth-rails_csrf_protection` (~> 2.0) are runtime dependencies. Development pins Recording Studio `v7.8.0`, FlatPack `v0.2.0`, Accessible `v0.58.0`, Admin `v2.20.0`, API `v1.21.2`, Attachable `v0.34.0`, Cache `v0.8.0`, Icons `v0.5.0`, Logs `v0.9.0`, Metrics `v0.10.0`, Moveable `v6.1.0`, and Trashable `v1.3.0`. The public `recording_studio_cache` requirement is `>= 0.5, < 1`. Admin and Accessible need `recording_studio_trashable` (`require: false`) for kept-SQL helpers. This gem enables Accessible and Attachable on Profile only. It does not enable either on People. Grants go through `bootstrap_owner_access!` / `grant_access` (`RecordingStudio::Access` is readonly). Attachable 0.22 registers `RecordingStudioAttachable::Attachment` only. Do not register `Library` or `Placement`.

The host remains responsible for its existing User and Devise setup, Active Storage, and the Attachable mount.

Then run:

```bash
bin/rails generate recording_studio_user:install
bin/rails generate recording_studio_user:migrations
bin/rails generate recording_studio_attachable:install
bin/rails generate recording_studio_attachable:migrations
bin/rails db:migrate
```

Register the gem's recordables next to the host's types, including Attachable's attachment type:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "RecordingStudioUser::People",
    "RecordingStudioUser::Profile",
    "RecordingStudioAttachable::Attachment"
  ]
end
```

Rerunning the installer is idempotent while the generated mount declaration remains intact. It mounts the engine with the `recording_studio_users` alias, injects `recording_studio_user_auth_for :users` when Devise is present, and creates `config/initializers/recording_studio_user.rb` only when that file does not already exist. The migrations generator copies the People and Profile tables. The installer does not generate a user model, users table, or Devise routes.

## Auth screens

The gem owns the default password login and sign-up chrome. Mount it after skipping Devise's own session screens:

```ruby
devise_for :users,
           skip: %i[sessions registrations passwords],
           controllers: {
             confirmations: "recording_studio_user/auth/confirmations",
             omniauth_callbacks: "recording_studio_user/omniauth_callbacks"
           }

recording_studio_user_auth_for :users
```

That draws `/users/sign_in`, `/users/sign_up`, and the complete password-reset
flow from `recording_studio_user/auth/*` — Flatpack forms on core
`recording_studio/default_layout`, no Card. The first screen is email only
(**Continue with email**), then social providers. Password or OTP is the
second screen, driven by `primary_login_type` (default `:email`). The
confirmations mapping gives Devise's resend screen the same chrome when
`:confirmable` is enabled. When `recording_studio_site_settings` is
installed, the site mark appears via `auth_site_logo` (optional
`config.auth_site_root_resolver`). `config.auth_logo` is `:square` by
default (Flatpack Avatar). Set `config.auth_logo = :wide` for the wide mark
as a `<img>` with an unsigned Active Storage blob path. That img uses
`max-h-16`, the same height as square Avatar `:xl`. If the wide file is
missing, the mark is omitted. Dummy keeps the square default.
`doc/review/users_sign_in_wide.png` and `doc/review/users_sign_up_wide.png`
are a temporary `:wide` flip against the seeded wordmark.

Auth screens call `recording_studio_layout { RecordingStudioUser.configuration.layout }`,
the same resolver as signed-in Users screens. `nil` uses
`RecordingStudio.configuration.layout`, then
`RecordingStudio::DEFAULT_LAYOUT` (`"recording_studio/default_layout"`). A
String names a layout. `false` renders with no layout. Do not set
`layout "recording_studio/default_layout"` on the controllers. Each view
wraps the form in `auth/_shell` (in-page content, not a layout): a centered
`max-w-sm` column with the site logo above a centered heading. Those screens
do not call `flat_pack_page_nav` and set `content_for :skip_page_nav` so
first screens have no Back/Close chevrons. They do not set
`content_for :title`, so Default Layout does not draw a second heading.
The default layout still renders `flash[:notice]` and `flash[:alert]`.
`:recording_studio_user_auth_body_start` renders at the start of the page
body so a host can inject markup without copying a layout. Unused, the slot
is empty.

To render the same partial on every unsigned auth page (sign in, sign up, and the rest), set `config.auth_body_start_partial` (default `nil`):

```ruby
config.auth_body_start_partial = "shared/views_tracking"
```

A view that already filled the slot with `content_for` wins, and the configured partial is not rendered. Set it from a view only when that one page should differ:

```erb
<% content_for :recording_studio_user_auth_body_start do %>
  <%= recording_studio_track_views %>
<% end %>
```

Signup and other unsigned auth forms render `config.signup_notice_partials` next to the submit button. The default is an empty list, which renders nothing. Each entry is a partial path, the same style as `auth_body_start_partial`:

```ruby
config.signup_notice_partials = ["shared/signup_notice"]
```

Put continue-notice copy in that partial. Record acceptance from `after_registration` (`user:` and `method:`, where `method` is `:password`, `:oauth`, or `:otp`). A valid submit is the consent.

The helper in that example is a host helper (for example from RecordingStudio_views). This gem does not depend on it. Do not prepend onto `AuthSiteLogoHelper` to fill this slot. A host that needs different chrome sets `RecordingStudioUser.configuration.layout` or `RecordingStudio.configure { |c| c.layout = ... }`. Password screens work with `otp_enabled` still `false`. Password sign-up still emails a confirmation code, so the code tables and `recording_studio_notifications` are required then too, and `/users/sign_up/verify` stays routed. A failed send does not keep the account. Login code routes (`/users/sign_in/otp`, `/users/sign_in/verify`) are drawn only when OTP login is on. The password sign-in code action is drawn only when a code screen exists. When those flags are off the missing paths are absent, not error pages. Hosts override a view only when the product must differ; do not copy the gem templates into the app. Place the override under the host `app/views/` with the same path as the gem (for example `app/views/recording_studio_user/auth/registrations/new.html.erb`). Host views win over the gem.

Route configuration values for `mount_path`, `profile_route_path`, and `admin_route_path` must be available **before the host evaluates the engine mount and Rails draws routes**:

```ruby
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.mount_path = "/account"
  config.profile_route_path = "me"
  config.admin_route_path = "user-reporting"
  # nil uses RecordingStudio.configuration.layout, then
  # "recording_studio/default_layout". A String names a layout. false
  # renders with no layout. A callable is call(controller:).
  # config.layout = "application"
  config.additional_profile_attributes = [:locale]
  # config.additional_profile_attributes |= [:nickname]
  config.require_password_confirmation = false
  # config.login_title = "Welcome back"
  # config.primary_login_type = :email # or :otp when OTP is enabled
  # config.auth_logo = :square # or :wide
  # config.auth_body_start_partial = "shared/views_tracking"
  # config.signup_notice_partials = ["shared/signup_notice"]
  # config.after_auth_path = ->(controller:, user:) { "/welcome" }
end
```

`primary_login_type` nominates what happens after the email step on both login and registration:

- `:email` (default) — next screen is password
- `:otp` — issues a code and opens the verify screen (requires `otp_enabled`, `otp_login_enabled`, `otp_registration_enabled`, and `:otp` in `registration_authentication_methods`)

Password sign-up always asks for an email code before the account is confirmed. The old `password_registration_confirmation` setting is gone, and assigning it raises. The password from that sign-up stays only for the browser that set it, and only when that same browser enters the code. Any other confirmation clears the password and any remembered sign-in. A password set after the account is confirmed stays. An unconfirmed account cannot sign in with a password. The password sign-in screen can email a confirmation code instead. When login codes are off, that button does not email a login code to a confirmed account, and an unknown address gets the same notice. The confirmation email is queued after the signup transaction commits. A failure while saving the account still rolls the account back.

Password sign-up routes are not drawn when `primary_login_type` is `:otp`, or when `registration_authentication_methods` does not include `:password`. Password sign-in stays for accounts that already have a password.

`Directory.create_user!` leaves the account unconfirmed unless the caller passes `confirm: true`. Staff create and connected-account create pass `confirm: true`. Public sign-up does not use that flag.

`auth_logo` nominates the Site Settings mark on those unsigned screens:

- `:square` (default) — app icon as a Flatpack Avatar
- `:wide` — wide mark as a proportioned `<img>`. Missing wide file omits the mark.

Host code uses the mounted-engine proxy:

```ruby
recording_studio_users.profile_path
recording_studio_users.edit_profile_path
recording_studio_users.admin_path
```

## Bring someone back after sign-in

A sibling gem can send a person through these screens and land them on a path in this host when sign-in finishes.

```ruby
recording_studio_user_sign_in_path(return_to: "/messages/42/join")
recording_studio_user_sign_up_path(return_to: "/messages/42/join", popup: true)
RecordingStudioUser.auth_url_for(:sign_in, return_to: "/messages/42/join")
```

A host can give one sign-up link its own title and subtitle. Register the name, and point `title` and `subtitle` at i18n keys. `subtitle` is optional.

```ruby
RecordingStudioUser.configure do |config|
  config.sign_up_variants = {
    trial: {
      title: "my_app.signup.trial.title",
      subtitle: "my_app.signup.trial.subtitle"
    }
  }
end

recording_studio_user_sign_up_path(variant: :trial, return_to: "/billing", popup: true)
RecordingStudioUser.auth_url_for(:sign_up, variant: :trial, return_to: "/billing")
```

That link is `/users/sign_up?variant=trial`. The page translates the keys for that name. An unknown name, a missing key, or any other query value keeps the default **Sign up** title and shows no subtitle. The page does not print the key, and it does not print text from the URL. A failed email submit on that page keeps the same title. The link from sign-up to sign-in does not carry `variant`. Put the strings in the host locale files. The dummy app registers `trial` in English and French.

`return_to` is accepted on the email step, the password step, one-time code request, verify, and resend, sign-up, password reset, confirmation, and the OAuth start. OAuth keeps the path in the session. It is not added to the provider URL.

The value has to be a relative path that starts with one `/`. One percent-decoding applies to the whole value, and anything longer than 2048 characters is dropped. The person then lands on the default page.

The path, the part before `?` or `#`, is dropped when it contains any of these:

- `//` or `/\`
- a backslash, a scheme (`word:`), a host, or userinfo (`@`)
- control characters, whitespace, or a unicode slash

The query and the fragment may hold a token. `//`, `:`, `@`, `+`, and `=` stay. They are still dropped for a backslash, a control character, whitespace, or a unicode slash. Prefer a url-safe token (base64url) in that query. A standard base64 token is kept, and a url-safe one survives more proxies.

A missing value uses the same fallback as a request that never passed `return_to`, `stored_location_for` or the host root.

Put a signed, purpose-scoped token in your own return path. About 15 minutes is a good lifetime. When the person comes back, check that they may do the action, then finish it with an idempotent POST. Do not finish the action on GET. This gem does not call back into the sibling.

`popup=1` is for an embed that opened sign-in in a new window. Auth responses stay out of frames with `X-Frame-Options: DENY` and `frame-ancestors 'none'`. After a successful sign-in the window posts `{ type: "recording_studio_user:signed_in" }` to the opener, then closes. The target origin is this host, plus any origin listed in `config.popup_opener_origins`. The post never uses `*`. If there is no opener, the window goes to `return_to`.

```javascript
window.addEventListener("message", (event) => {
  if (event.origin !== window.location.origin) return;
  if (!event.data || event.data.type !== "recording_studio_user:signed_in") return;
  window.location.reload();
});
```

An embed on another origin adds that origin to `config.popup_opener_origins` and checks `event.origin` against the same list. OTP, account creation, signup terms, confirmations, and rate limits stay on their host flags. `return_to` does not turn them on.

## Email a link that starts a code sign-in

A sibling gem can put a link in an email. The link names one existing person and a path on this host. Opening it starts the usual code sign-in for that person. The link does not sign anyone in, and it does not create an account.

```ruby
RecordingStudioUser.code_sign_in_url(
  user: user,
  return_to: "/notifications/settings",
  title: "notifications.mail.settings_title",
  reason: "notifications.mail.settings_reason",
  expires_in: 30.days
)
```

`title` and `reason` are optional i18n keys, not sentences. They are signed into the token. A hash adds interpolation params: `reason: { key: "notifications.mail.settings_reason", product: "Notifications" }`. A missing translation uses the usual code-screen title and omits the reason. `code_sign_in_path` is the same link without a host. `expires_in` defaults to 30 days. Set the mailer host the same way you do for other mail, because the URL helper reads `default_url_options`.

Notifications can use that URL as the footer link to notification settings:

```ruby
def notification_settings_url(user)
  RecordingStudioUser.code_sign_in_url(
    user: user,
    return_to: "/notifications/settings",
    title: "notifications.mail.settings_title",
    reason: "notifications.mail.settings_reason"
  )
end
```

Messages can pass a conversation path. Support can pass a ticket path. The return path has to be a relative path on this host. `ReturnTo` drops an absolute or external value, and sign-in then uses `config.after_auth_path` or the host root.

The token is a Rails signed message with purpose `recording_studio_user/code_sign_in`. It carries the user id, the normalized email, the safe return path, the Devise `authenticatable_salt` when the user has one, and any `title` or `reason` key. Changing the email, the password, or those keys makes older links fail. There is no new column and no migration.

The first request stores the token in the session and redirects to the same path with no token, so the token stays out of the next page's Referer. `code_sign_in_token` is in `filter_parameters`.

What the person sees:

- The link is invalid, expired, or void. They land on the normal sign-in screen with one notice. The notice does not say whether an account exists.
- They are already signed in as that person. They go to the return path and no code is sent.
- They are signed in as someone else. The screen shows the masked address from the link and a button to sign out. Signing out continues into the code sign-in. The account does not switch on its own.
- They are signed out, the person is confirmed, and login codes are on. The usual login code is emailed. The code screen title is the translated `title`, or "Enter your code". Under it: "We just sent a code to" the masked address, then the translated `reason` when one was given. That screen does not use the "eligible account" notice. Resend stays "Resend code". A correct code runs the normal sign-in, including session rotation. `config.after_auth_path` still wins over `return_to`. The ordinary sign-in screen still uses the "eligible account" notice.
- The person is not confirmed, or login codes are off. They get the same sign-in screen as a bad link. No account is created.

This is separate from the one-time sign-in link sent while codes are paused. That link signs the person in when they submit it. This link only chooses who receives a code.

## Land on a host path after sign-in or sign-up

`config.after_auth_path` (default `nil`) is a callable. Password, OAuth, one-time code, and the sign-in link all ask it where to go, for a sign-in and for finishing a sign-up. A path is the redirect. `nil`, or a callable that returns `nil`, keeps the stored `return_to` or the host root.

```ruby
RecordingStudioUser.configure do |config|
  config.after_auth_path = ->(controller:, user:) { "/welcome" }
end
```

A Terms and Conditions host sends someone with pending terms to Accept and leaves everyone else on that default:

```ruby
config.after_auth_path = ->(controller:, user:) {
  RecordingStudioTermsAndConditions::Gate.after_auth_path(controller, user)
}
```

`Gate.after_auth_path` returns nil when nothing is pending. Set the callable in the host initializer. The auth controllers read it in one place.

## Send a code when you already have the email

A contact form or another gem can skip the email screen. POST the address. Do not put it in a URL or a GET.

```ruby
# A host controller that already collected the address
result = RecordingStudioUser.start_otp_challenge!(
  request: request,
  email: email,
  return_to: "/messages/42/join",
  popup: params[:popup]
)
if result.throttled?
  redirect_to recording_studio_user_otp_challenge_path, alert: t("recording_studio_user.auth.give_it_a_minute")
else
  redirect_to recording_studio_user_otp_challenge_path
end
```

Or POST `email`, `return_to`, and optional `popup=1` to `recording_studio_user_otp_start_path` with the Rails CSRF token. That action stores the pending email and the safe return path the same way the normal flow does, asks for a code with `request_otp!`, and redirects to the code page.

The code page shows the code field, a masked address, resend, and a link back to the normal sign-in screen (still carrying `return_to`). No password, social buttons, or sign-up form. A valid code goes to `return_to`, or to the popup completion page when `popup=1`.

An existing person gets a sign-in code only when `otp_enabled?` and `otp_login_enabled?` are on. A new address creates an account only when `otp_enabled?` and `otp_registration_enabled?` are on. `after_registration` runs for that new account. Otherwise nothing is sent and no account is created. The redirect and the notice stay the same either way. Rate limits match the other code requests, per email and per IP. The route is absent when one-time codes are off.

## Pass a signup source

A sibling gem can record where a new account came from. Call one of the two methods below from server-side Ruby. This gem stores the hash in the session and copies it onto `registration.completed.recording_studio_user` when the account is created. It never reads `source` from a form, a query string, `POST` `auth/otp/start`, or an OAuth start URL.

Use `remember_signup_source!` when you redirect to the built-in password, one-time code, or OAuth sign-up page.

```ruby
RecordingStudioUser.remember_signup_source!(
  request: request,
  source: { kind: "press_contact", recording_id: recording.id }
)
```

Use `source:` on `start_otp_challenge!` when you already have the email and start the code yourself.

```ruby
RecordingStudioUser.start_otp_challenge!(
  request: request,
  email: email,
  source: { kind: "kit_download" }
)
```

`source` is a Hash with at most 8 keys. Each key is a symbol or a string matching `[a-z_][a-z0-9_]{0,39}`. Each value is a string of at most 255 characters, a symbol, an integer, `true`, `false`, or `nil`. Any other shape raises `ArgumentError`. Values are not checked against a list.

The event gains `source:` only when a hash was stored. Keys on the event are symbols. With no source, the payload stays `{ user_id:, method: }`.

An `after_registration` hook written as `->(user:, method:)` keeps working. Declare `source: nil` to receive the hash on sign-ups that have one, and nil on sign-ups that do not.

The session entry is removed when the event is emitted. A later registration in that session does not see it. The hash is not saved on the user and not saved on the one-time code. Sign-in does not emit it.

A host that calls `complete_registration!` or `complete_email_proof!` itself must pass `session:` when the stored source should reach the event. The built-in OTP screens already pass it to `complete_registration!`.

A recording id inside `source` is a hint. Check access with Recording Studio Accessible before you show that recording or pick a screen from it. This gem does not grant access.

## A code box inside your own modal

On this same host, render the box in a modal you already own. It does not bring the auth logo or page layout. Leave the modal title blank so the close control sits alone. Pass `title:` when the heading should sit on its own line above the hint.

```erb
<%= render RecordingStudioUser::OtpCodeForm.new(
  masked_email: masked_email,
  title: t("recording_studio_user.sessions.enter_code")
) %>
```

`RecordingStudioUser::OtpCodeForm.mask(email)` returns the same short mask the code page uses. The markup also lives at `recording_studio_user/otp/inline_code_form` if you need the partial.

The form posts to the same start, verify, and resend actions. Resend stays a POST, drawn as a text link beside the link back to sign-in. Without JavaScript that is a normal POST and the browser follows the redirect. With Turbo, the form targets the frame `recording_studio_user_otp_inline`, so an error, a resend notice, or success replaces that frame and the modal stays put. Success dispatches `recording_studio_user:signed_in` on `document`. `detail.return_to` is the safe path. `detail.csrf_param` and `detail.csrf_token` are the fresh token from the rotated session. The same script writes those values into `meta[name="csrf-param"]` and `meta[name="csrf-token"]` when the tags are already on the page. Use that token on the next POST.

A caller that wants JSON sends `Accept: application/json` and the CSRF token. Start and resend return `{ "ok": true }` (or a 429). A valid code returns `{ "ok": true, "return_to": "/messages/42/join", "csrf_param": "authenticity_token", "csrf_token": "..." }` and signs the person in, including the usual session rotation. Session rotation changes the CSRF token. The JSON body carries the new one and does not include the email address.

Configured `signup_notice_partials` render in the box above Continue, the same slot as the full-page code form. A valid code finishes a new account without an extra parameter. `after_registration` runs for that new account.

A request with an `Origin` other than this host is rejected. Nothing on these actions adds CORS headers, and auth responses stay frame-denied. Login, registration, rate limits, and the single registration event follow the same rules as the code page.

## Social sign-in

The dummy app's Google client is **RecordingStudioUsers** in the [BowerBird Dev](https://console.cloud.google.com/auth/clients?project=key-buttress-507301-d2) GCP project ([client](https://console.cloud.google.com/auth/clients/332241240783-36h23frfv5ovlnqtkcc3cc1a96afqkji.apps.googleusercontent.com?project=key-buttress-507301-d2)). Redirect URI: `http://localhost:3000/users/auth/google_oauth2/callback`. See `test/dummy/README.md`.

Continue-with buttons appear only for providers whose secrets are present in Rails credentials under `omniauth:`. An empty `omniauth_providers` hash (the default) reads those credentials. Commented-out or blank credential keys stay hidden. Do not use environment-variable fallbacks or OmniAuth test mode in the app.

Add keys with `bin/rails credentials:edit` (or `--environment development`):

```yaml
omniauth:
  google_oauth2:
    client_id: your-google-client-id
    client_secret: your-google-client-secret
  # microsoft_graph:
  #   client_id: your-microsoft-client-id
  #   client_secret: your-microsoft-client-secret
  # apple:
  #   client_id: your-apple-client-id
  #   client_secret: ""
  #   team_id: your-apple-team-id
  #   key_id: your-apple-key-id
  #   pem: |
  #     -----BEGIN PRIVATE KEY-----
  #     ...
  #     -----END PRIVATE KEY-----
  # linkedin:
  #   client_id: your-linkedin-client-id
  #   client_secret: your-linkedin-client-secret
  # instagram:
  #   client_id: your-instagram-client-id
  #   client_secret: your-instagram-client-secret
```

`config.omniauth_create_account` still controls whether an unknown provider email creates a User. An explicit non-empty `omniauth_providers` hash still overrides credentials. Apple also accepts `team_id`, `key_id`, `pem`, and `scope`. Point host Devise callbacks at the engine controller:

```ruby
devise_for :users,
           skip: %i[sessions registrations passwords],
           controllers: {
             confirmations: "recording_studio_user/auth/confirmations",
             omniauth_callbacks: "recording_studio_user/omniauth_callbacks"
           }
recording_studio_user_auth_for :users
```

Render is no longer required in host Devise views when you use `recording_studio_user_auth_for` — the gem auth screens already include `recording_studio_user/omniauth/continue_with_providers`. The partial draws a Flatpack Divider labeled Or, then one Continue-with button per configured provider. The engine adds `:omniauthable` only when providers are configured. Run `bin/rails generate recording_studio_user:migrations` and `bin/rails db:migrate` to restore the identities table; the 0.6.2 migration is safe whether a host retained or dropped the 0.6.0 table.

On callback, Users first finds `provider` + `uid`. For a new identity, it normalizes the provider email and automatically links it to the existing User with that email. An email explicitly marked unverified by the provider is rejected. If the User supports Devise Confirmable, an unconfirmed existing email is also rejected. Hosts without Confirmable must otherwise verify email ownership during password registration before enabling automatic social-account linking. If no User matches, `omniauth_create_account` controls whether `Directory.create_user!` creates the User and Profile. Setting it to `false` fails closed for unknown emails. OAuth tokens are not stored.

**Sign-in methods** lists only providers that are still configured. An identity for a provider whose credentials were removed is inert — no strategy or callback route exists for it — so it is hidden and does not count as a remaining sign-in method when disconnecting. Delete those rows with:

```bash
bin/rails recording_studio_user:prune_unconfigured_identities
```

First login requires an email. Instagram often returns none, and Apple may return an email only on first consent or use a private relay; those first logins fail closed when no email is available. A signed-in user can still connect such a provider from **My Profile → Sign-in methods**, because the provider identity can safely attach to the current User without inventing an email. Disconnect is blocked when it would remove the only sign-in method from a user without a password.

## Events

Successful registration emits one ActiveSupport::Notifications event after the
creating transaction commits:

```ruby
ActiveSupport::Notifications.subscribe(
  "registration.completed.recording_studio_user"
) do |_name, _start, _finish, _id, payload|
  # payload: { user_id:, method: } — method is :password, :oauth, or :otp
  # source: is added only when a sibling gem passed one. See "Pass a signup source".
  user = User.find(payload[:user_id])
end
```

| Path | When it fires | `method` |
| --- | --- | --- |
| Password sign-up | When the email code confirms the new account | `:password` |
| OAuth | Only when `create_user_from_auth!` creates a **new** user | `:oauth` |
| OTP registration | Alongside the existing OTP event below | `:otp` |
| Email proof | When `complete_email_proof!` confirms an account that was not confirmed yet. Pass `session:` to include a stored source. | `:otp` |

It does **not** fire for password or OAuth login, for `complete_email_proof!` on an already confirmed account, for linking an OAuth identity
to an existing user, or when password sign-up fails validation.

OTP registration still emits the legacy event unchanged:

```ruby
"otp.registration_completed.recording_studio_user"
# payload: { user_id:, challenge_id: }
```

Other OTP instrumentation (`otp.*.recording_studio_user` for issue/verify and
`otp.email_proof_completed.recording_studio_user`) is unchanged.

## After-registration hooks

Hosts that need their own work on sign-up (beyond subscribing to the event)
register one or more `after_registration` callbacks. They run in the same
`after_all_transactions_commit` callback as the event above, after the event
is instrumented. With no signup source, the payload stays `{ user_id:, method: }`.
RecordingStudio_onboarding and other subscribers keep working. A hook that
declares `source: nil` also receives the hash from "Pass a signup source".

```ruby
RecordingStudioUser.configure do |config|
  config.after_registration ->(user:, method:) {
    # method is :password, :oauth, or :otp
    Host::WelcomeMailer.deliver_later(user)
  }

  # Or a class-name string whose constant responds to .call(user:, method:)
  config.after_registration "Host::ProvisionWorkspace"
end
```

Multiple registrations are allowed; each runs in order. A hook error is logged
and reported through `Rails.error` and does not break sign-up or later hooks.
Hooks do **not** run on login or when an OAuth identity is linked to an
existing user. A continue-notice belongs in `signup_notice_partials`. Record
acceptance inside one of these hooks.

## User contract

The configured `user_class_name` must name the existing, Devise-compatible Active Record class returned by `current_user`. It must use the host's UUID primary key and provide `email`, password digest, and timestamps. It must **not** store `first_name`, `last_name`, `time_zone`, or `additional_profile_attributes` — those belong on Profile.

## People and Profile

People is a shared root. Nobody owns the forest through that root node. Accessible and Attachable are enabled on Profile, the domain child, not on People.

```ruby
class RecordingStudioUser::People < ApplicationRecord
  recording_studio_recordable label: "People", root: true, shared: true
end

class RecordingStudioUser::Profile < ApplicationRecord
  ALLOWED_PARENT_TYPES = ["RecordingStudioUser::People"].freeze

  recording_studio_recordable label: "Profile",
                              root: false,
                              allowed_parent_types: ALLOWED_PARENT_TYPES
  RecordingStudio.enable_capability(:accessible, on: self)
  include RecordingStudio::Capabilities::Attachable.to(
    allowed_content_types: ["image/*"],
    enabled_attachment_kinds: %i[image],
    max_file_count: 1
  )
end
```

`max_file_count` is the Attachable per-upload batch limit, not a lifetime cap. The product still shows one image: upload when empty, replace when present.

Profile snapshots hold `first_name`, `last_name`, `time_zone`, and `additional_profile_attributes`. Writes go through public helpers, never raw `Recording` / `Event` inserts:

```ruby
user = RecordingStudioUser.create_user!(
  email: "ada@example.com",
  password: "Password123!",
  first_name: "Ada",
  last_name: "Lovelace",
  time_zone: "UTC"
)

RecordingStudioUser.display_name_for(user) # => "Ada Lovelace"
RecordingStudioUser.profile_for(user)

RecordingStudioUser.record_profile!(
  user,
  first_name: "Ada",
  last_name: "Byron",
  time_zone: "UTC"
)

RecordingStudioUser.attach_profile_image!(
  user,
  io: File.open("ada.png"),
  filename: "ada.png",
  content_type: "image/png"
)
RecordingStudioUser.profile_image_recording_for(user)
```

`create_user!` creates the Devise user, then `people_root.record(Profile)`, then `RecordingStudioAccessible.bootstrap_owner_access!` on that Profile recording (role `:admin`). Do not bootstrap People — Accessible rejects the shared root on purpose. Later membership uses `grant_access`. Later profile changes `revise` the existing recording so a new snapshot row is created. `display_name_for` reads the current Profile, then a custom `full_name` / `name`, then email.

`attach_profile_image!` calls Attachable's `ImportAttachment` on the Profile recording. `replace_profile_image!` issues the blob through Attachable direct upload after `Authorization.authorize!(action: :upload)` in `ProfileImage::Blobs`. Edit Profile does not duplicate that check. A second call returns the existing image. `replace_profile_image!` swaps the file on that same attachment through `replace_attachment_file`. `assign_profile_image!(user, signed_blob_id:, actor:)` attaches or replaces a blob already issued by Attachable direct upload. `remove_profile_image!` trashes that attachment. Edit Profile uses `FlatPack::ImageInput::Component` (`shape: :circle`, `size: :"2xl"`) inside the profile form. Choosing a file direct-uploads through `recording-studio-attachable--attachment-revision-upload`; **Update profile** submits the signed id. Clear is available only when a photo is already saved. My Profile shows the Avatar only. Neither screen opens Attachable's Name / Description record edit.

`additional_profile_attributes` on configuration is an allowlist of extra keys stored in the Profile jsonb column. `:locale` is on that list by default so a signed-in preferred language can persist for Recording Studio Internationalization (`additional_profile_attributes["locale"]`). Identity, credential, authorization, membership, root, recording, and recordable fields stay protected. Edit Profile shows a Language select when `:locale` is allowlisted. Blank unsets the key so the host can fall back. Add more keys with `|=` so you do not drop locale:

```ruby
RecordingStudioUser.configure do |config|
  config.additional_profile_attributes |= [:nickname]
end
```

Hosts that still assign `config.additional_profile_attributes = []` hide Language and Internationalization will only use the cookie. There is no `locale` column — extras stay in jsonb.

`require_password_confirmation` defaults to `false`. Host Devise sign-up should hide the confirmation field and skip the param when this is `false` (the default). Set it to `true` to show confirmation. The included `ProfiledUser` concern copies `password` into `password_confirmation` so Devise Validatable does not fail when confirmation is off.

`minimum_password_length` defaults to 12. `ProfiledUser` rejects a shorter password itself, so a host `Devise.password_length` of `6..128` does not let a shorter password through. Set the host Devise minimum to the same number so the two messages agree. Sign-up and reset show this gem minimum. The dummy app sets Devise `password_length` to `12..128`.

`login_title` defaults to the I18n string `recording_studio_user.auth.login_title` (`Welcome back` in English). Blank values fall back to that translation. Hosts that add another language translate that key. Set `config.login_title` only when the host wants a fixed heading that does not switch language.

## Translations

The engine ships English defaults in `config/locales/en.yml` under `recording_studio_user.*` and adds that file to the host I18n load path. Auth screens, profile screens, flashes, OTP mail copy, and OmniAuth alerts resolve those keys at request time. `recording_studio_user.profile.unnamed_user` remains the fallback display name when a person has no email and no profile name.

Other languages are the host's job. Copy the same keys into `config/locales/<locale>.yml` and list that locale in `config.i18n.available_locales`. A host key with the same name overrides the English default. The dummy app's `test/dummy/config/locales/fr.yml` is a complete French override you can copy.

Edit Profile's Language select lists `I18n.available_locales` (or Recording Studio Internationalization's available locales when that gem is loaded). The blank option is `Default {site language}` and unsets the saved preference. Restrict `config.i18n.available_locales` to the languages you offer — Devise and other gems may otherwise load a long list.

This gem does not switch the request locale on its own. Recording Studio Internationalization can still read and write the signed-in `locale` extra. The dummy app demonstrates a host French override via `?locale=fr`, a submitted Language on Edit Profile, or a saved profile locale (`dummy_locale` cookie follows the resolved locale so POST and redirects keep it). English and French review shots live in `docs/review/` as `en-*.png` and `fr-*.png`.

`primary_login_type` defaults to `:email`. Set `:otp` only when OTP is fully enabled; the config fails closed if OTP flags are off.

## Email OTP authentication (opt-in)

OTP registration and login are **disabled by default**. Turn them on only after running the OTP migrations and installing `recording_studio_notifications` with the email channel gem (and push, if you want login codes on devices).

```ruby
RecordingStudioUser.configure do |config|
  config.otp_enabled = true
  config.otp_registration_enabled = true
  config.otp_login_enabled = true
  config.registration_authentication_methods = %i[password otp]
  config.otp_registration_channels = %i[email]
  config.otp_login_channels = %i[email push]
  # Optional: make the email code the second screen after Continue with email
  # config.primary_login_type = :otp
end
```

```bash
bin/rails generate recording_studio_user:migrations
bin/rails db:migrate
```

Mount the auth screens with `recording_studio_user_auth_for :users` (see Auth screens above). Password sign-up and sign-in keep working with OTP off. The migrations generator backfills `registered_with` (and renames `authentication_method` when that column is still present), adds Devise confirmable columns with `confirmed_at` for existing users, creates the OTP challenges table, adds the open-challenge unique index, and creates the password-failure and sign-in-lock tables. Route mapping lives in Auth screens above.

Hosts that prove an email address from another gem call these methods. They never load `OtpChallenge` or the rate limiter.

`request_otp!` is the call for both registration and login. It normalizes the email, reserves the rate limit, finds or creates the unconfirmed user, then issues the code. Login does not create a user. A throttled request creates nothing. Unknown, existing, disabled, and password-registered addresses get the same check-email response. Disabled addresses are skipped and no code is sent. The result status is `:issued`, `:throttled`, or `:suppressed`.

```ruby
issued = RecordingStudioUser.request_otp!(
  email: email,
  purpose: :registration, # or :login
  request: request,
  session: session
)
issued.status # :issued, :throttled, or :suppressed
issued.challenge_id if issued.issued?

proof = RecordingStudioUser.otp_proof(issued.challenge_id)
# proof.purpose is "registration" or "login"; missing/consumed/revoked is nil

RecordingStudioUser.otp_message(issued.challenge_id)
# { title:, body:, url: } while the challenge is deliverable, otherwise nil

verified = RecordingStudioUser.verify_otp!(
  challenge_id: issued.challenge_id,
  code: code,
  purpose: proof.purpose,
  session: session
)
verified.success?
verified.user

RecordingStudioUser.complete_email_proof!(
  user: verified.user,
  challenge_id: issued.challenge_id,
  profile_attributes: { first_name: "Ada", last_name: "Lovelace" },
  session: session
)

RecordingStudioUser.resend_otp!(
  user: user,
  purpose: proof.purpose,
  request: request,
  session: session
)
```

`resend_otp!` uses the same email digest as `request_otp!` and returns the same result object. Check `result.throttled?` when a code request is too soon. Send and resend share that email bucket, and the bucket uses `otp_resend_cooldown`. IP and session buckets stay on their own scope. Resend's IP and session keys still use `otp_resend_cooldown`. Callers pass each key as email, IP, or session.

The email rate-limit bucket is an HMAC-SHA256 of the normalized address. The HMAC key is derived from `secret_key_base`, so the cache does not store the address. Email, IP, and session are all read before any of them is consumed: a block on one key does not spend the others. Those counters need a shared, atomic cache store (Redis or Memcached) because every app process has to see the same numbers. A memory store, a null store, or a file store cannot share limits across hosts. When one-time codes are on and `Rails.cache` is one of those, boot raises outside development and test and logs a warning in development and test. Password sign-in and reset limits use that same check.

Wrong codes are counted per account across registration, login, and confirmation challenges created in `otp_lockout_window` (default 1 hour) and after the latest consumed challenge. `otp_lockout_max_failures` defaults to 10. At that point the account's codes pause for `otp_lockout_duration` (default 1 hour). A correct code during the pause gets the same response as a wrong code. Requesting or resending a code during the pause returns the usual "code sent" response. Instead of a code, that request emails one sign-in link. The link stores only a digest, expires with `otp_expires_in`, works once, and is bound to that user. Opening it shows a confirmation page and does not use the link. Submitting that page signs the user in and clears the code pause and the password pause. The email is queued the same way as a code email. The link is not guessable, so the code pause does not apply to it. One email is sent when a pause starts. Password sign-in is not paused by a code lock.

The host needs a case-insensitive unique index on `users.email` (a unique index on `LOWER(email)` is the usual shape). `create_unconfirmed_user!` rescues `ActiveRecord::RecordNotUnique` and returns the row that won the race. Open challenges — not consumed and not revoked — have a partial unique index on `recording_studio_user_otp_challenges` `(user_id, purpose)`.

`complete_email_proof!` confirms the account after a successful verify. When that call confirms an account that was not confirmed yet, it emits `registration.completed.recording_studio_user` with `method: :otp` after the transaction commits. `after_registration` hooks run for that confirmation. Pass `session:` to copy a stored signup source onto the event and then clear the session key. Without `session:`, the event still fires and the payload is `{ user_id:, method: :otp }`. The call does not read or clear a session it was not given. An already confirmed account is a sign-in, and that call does not emit `registration.completed`. `otp.email_proof_completed.recording_studio_user` still fires. The call does not change `registered_with` or the password. A new profile stores the submitted names. A one-word name has no surname, and no time zone is set. An existing profile is left alone. Raise `ArgumentError` when the challenge was not verified first. The shared email bucket uses `otp_resend_cooldown`. Resend's IP and session keys use `otp_resend_cooldown`.

`complete_registration!` is the Users sign-up path. It still requires an OTP account and still fills a default surname and UTC.

`registered_with` records how the account was created, not the only way it can sign in:

- **Password accounts** can sign in with their password *or* request an email code. Having a password is a capability, not a restriction.
- **OTP accounts** have no usable password, so they sign in with email codes only.

Password sign-in shows the same mismatch notice for an unknown email, a wrong password, an OTP-only account, and a request over the limit. An unknown email, an OTP-only account, and an unconfirmed account run the same password digest compare as a real password check. A blocked request does not check the password. Password reset shows the same Devise send-instructions notice for a known address, an unknown address, an OTP-only account, and a request over the limit. `Devise.paranoid` does not change that notice, and the response never says the address was not found. Reset does not email OTP-only or unknown addresses, and it does not send another email once the limit is spent. Sign-up still returns an error for an existing email. Login codes go to any confirmed, active account. Requesting one for an unknown, unconfirmed, or inactive email renders the same verify page and sends nothing.

Sign-in allows 5 requests per email and 10 per IP every 3 minutes (`password_sign_in_email_limit`, `password_sign_in_ip_limit`, `password_sign_in_period`). Reset allows 3 per email and 10 per IP every 15 minutes (`password_reset_email_limit`, `password_reset_ip_limit`, `password_reset_period`). The email key is the same HMAC of the normalized address that one-time codes use. Both keys are read before either is counted, so a block on one does not spend the other. The counters are `RecordingStudioCache::RateLimiter` on `Rails.cache`. Use Redis or Memcached. A memory store, a null store, or a file store cannot share the counts across hosts. Boot raises outside development and test when the cache is one of those, and logs a warning in development and test. This is not Devise lockable.

Wrong passwords on an account are also stored in `recording_studio_user_password_failures`. `password_lockout_max_failures` defaults to 10 inside `password_lockout_window` (default 1 hour). The account's password sign-in then pauses for `password_lockout_duration` (default 1 hour). A correct password during the pause gets the same mismatch notice as a wrong password. A successful password sign-in clears the count. A completed password reset clears it too, and so does signing in with the link sent while codes are paused. One email is sent when a pause starts. A code lock does not pause password sign-in. Run `rails generate recording_studio_user:migrations` for the password-failure, sign-in-lock, and sign-in-link tables.

Login notifications link to a protected code page under the Users mount. The
page decrypts the code only while its challenge is active and only for the
recipient; the plaintext code is never stored on the notification. Used,
revoked, expired, and over-attempted challenges show a request-new-code state.

Email and push resolve their title and body at delivery time through
`RecordingStudioNotifications.register_delivery_payload_resolver`. Hosts can
replace the `:registration_otp` or `:login_otp` resolver to customize channel
copy without changing the persisted notification or the protected code page.

Mounted profile show/edit/update still authenticate with Devise, then authorize with `RecordingStudioAccessible.authorized?` on the current user's Profile recording. Do not add a `current_user`-only ACL, `can_access?`, or hand-built Access rows.

Flash notices come from the host layout. Profile show does not render `notice` again. When the host uses Recording Studio's default layout, that layout already draws `flash[:notice]` as a FlatPack alert.

Profile is not a place to grant other actors. First-owner bootstrap is how the owner is recorded. Do not put `recording_access_management_link` on these screens.

Show sets `content_for :title` to **My Profile**. The default layout draws that string once, as the page `<h1>`. There is no second `FlatPack::PageTitle` in the view. `flat_pack_page_nav` puts Close on the left. `register_page_nav` puts **Edit** (`role: :primary`) on the right, and **Sign-in methods** (`role: :secondary`) when OmniAuth is configured. The card uses `shadow: :md`. A Grid `cols: 2` wraps the Card only so it occupies one cell on a wide screen. Inside the card, Avatar sits above unlabeled name, email, and time zone — one column on desktop and phone. Empty photos use Avatar's person icon, not initials. There is no show subtitle and no city field. Edit sets `content_for :title` and a short `content_for :subtitle`, and `flat_pack_page_nav` adds Back to the profile plus Close. Edit hosts `#profile-photo` with `FlatPack::ImageInput::Component` (`attachment_preview_url(..., variant: :square_med)`, `size: :"2xl"`, `shape: :circle`) wired to Attachable direct upload. The submit row uses `pt-4`, then stacked fields, in a Flatpack Grid `cols: 2` so the form sits in one cell on large screens. An `mb-8` wrapper under the helper puts a field of air between the avatar and First name. First name, Last name, and Time zone stay full-width rows. Update profile and Cancel are two separate Flatpack buttons sitting next to each other, not a ButtonGroup. The edit subtitle names name, time zone, photo, and language when locale is allowlisted.

## Users administration

The engine still registers a reusable `users` section, a site-level `recording_studio_users` screen, and a compact total-users widget with `RecordingStudioAdmin`. The read-only screen lists name, email, and created-at. The gem does not add user editing, deletion, impersonation, password operations, or admin/role columns.

When Recording Studio API is present, the engine registers users endpoints on the host's named `:operations` API. Hosts that already define `config.api :operations` (for example featured_in) do not need a second named-API block in this gem. The gemspec depends on `recording_studio_api` `>= 1.1`, `< 2.0`. There is no `users/count` endpoint; read the user total from the `users.total` metric (see below).

The `:operations` API registers `GET users`, `GET users/:id`, `POST users`, and `PATCH users/:id`. There is no `DELETE`, and none of these routes are on the public API. List and show need Accessible `:view` on AdminRoot. Create and update need `:edit`. `POST` with a password calls `create_user!`. Omit the password and, when one-time codes are enabled, `POST` calls `create_unconfirmed_user!` (unconfirmed `registered_with: otp`) and `record_profile!` when profile fields are present. When one-time codes are off, that request returns `422` and `password is required`. Admin create does not emit `registration.completed`. `PATCH` updates profile fields through `record_profile!`, bumps the Devise user's `updated_at`, and rejects `email`. Extra keys on create or update return `422` with `Unknown parameters` naming the field. Extra query keys on list are ignored. `users` declares `page` and `per_page` (`reject_unknown: false`); `users_create` and `users_update` declare writable fields with `input_contract` on `register_endpoint` so OpenAPI and MCP list them (`reject_unknown: true`). Contract and examples: **[docs/api.md](docs/api.md)**.

The engine also registers a `:users` metrics resource with RecordingStudioMetrics (`blast_radius: :site`, AdminRoot `:view` via `RecordingStudioUser::Api::Access.can_view?`). The metrics are `users.total`, `users.signups`, `users.total_over_time`, `users.by_method`, and `users.confirmation` when `confirmed_at` exists. It also registers an `:otp_challenges` resource on `RecordingStudioUser::OtpChallenge` with the same site blast radius and the same AdminRoot `:view` check. Both resources are exposed on `:operations` only.

API 0.11 can list metrics with `register_recordable_type_api` and `metrics:`. Users does not call it for `User`. That registration takes `GET` and `POST /users` off the custom handlers, and `GET /users/metrics/users.total` counts recordings of type `User`, which this gem does not create. The operations users routes stay the custom endpoints. `metrics_for("User", api: :operations)` stays empty.

When Recording Studio MCP is loaded, the engine registers named tools for `users`, `users_create`, `users_show`, and `users_update` through `RecordingStudioMcp.register_tool`. Catalog metrics stay catalog tools. Hosts include them by name:

```ruby
include_tools *RecordingStudioUser::McpCopy.tool_names(api: :operations)
```

That list is `users-total`, `users-signups`, `users-total_over_time`, `users-by_method`, `users-confirmation`, and `otp_challenges-failed_over_time`. `users-confirmation` is omitted when the users table or `confirmed_at` is missing, matching `Metrics.define_confirmation`. Endpoint MCP copy lives in `RecordingStudioUser::McpCopy`. Metric MCP titles and descriptions come from the metric catalog (MCP has no metric-copy overlay). API OpenAPI stays plain and names view or edit access to the admin area. An operations client that passes `RecordingStudioUser::Api::Access.can_view?` sees those metric tools. `users-signups` and `users-total_over_time` accept `from`, `to`, and `interval`. The other three users metrics accept none of those. None of the five users metrics accept `group_by` or `filters`. A client that fails the check does not see the tools. `RecordingStudioMcp::MetricTools.execute` of `users-total` for that client raises `RecordingStudioApi::AuthorizationError`. This gem does not depend on MCP. Contract: **[docs/api.md](docs/api.md)**.

`otp_challenges.failed_over_time` (unit `count`) is a time series of failed OTP challenges. A challenge counts as failed when `VerifyOtp` locks it: each wrong code calls `OtpChallenge#increment_attempts!`, which revokes the challenge once `attempts_count` reaches `otp_max_attempts`. Each locked challenge counts once, in the bucket of its `revoked_at`. These are not counted: challenges revoked because `IssueOtp` sent a new code (they are revoked below the limit), challenges that expired unused, and single wrong codes on a challenge that was not locked. None of these has a failure timestamp. The scope reads the current `otp_max_attempts`, so lowering it later also counts older superseded challenges that already had that many wrong codes. The metric takes `from`, `to` and `interval` (`day`, `week`, `month`, `year`). It can be grouped by `purpose` (`registration` or `login`). Groups with fewer than 5 challenges in the period fold into `other`. There is no failure-reason column, so it cannot be grouped by reason. It cannot be grouped by user, email or phone. No OTP list endpoint exists, so the metric has no filters.

This gem does not call `RecordingStudioMetrics::Api.register!`. The host registers Metrics endpoints once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

The host owns administration and must create its admin recordable/root, mount RecordingStudioAdmin, and grant first-owner `:admin` access on the empty owned admin root with `RecordingStudioAccessible.bootstrap_owner_access!`.

## Dummy app

The dummy mounts Users auth with `recording_studio_user_auth_for :users`. Login, sign up, password reset, and resend confirmation are gem screens on core `recording_studio/default_layout` through `recording_studio_layout`, no Card, no Remember me, no seed Badge. First screens are email only with **Continue with email**, then `continue_with_providers`. Password is the second screen when `primary_login_type` is `:email` (the default), with a **Forgot your password?** link into the reset flow. Login uses `login_title` (I18n default **Welcome back** in English). Dummy registers a `trial` sign-up variant, so `/users/sign_up?variant=trial` shows **Start your trial**. Dummy ships its own `config/locales/fr.yml` and can switch Users screens with `?locale=fr` or a saved profile locale. Sign-up confirmation appears only when `require_password_confirmation` is true. Dummy credentials (`test/dummy/config/credentials.yml.enc` and `test/dummy/config/credentials/*.yml.enc`) use the shared RecordingStudio_* development master key — set `RAILS_MASTER_KEY` or put that key in the gitignored dummy key files; keep the encrypted files and do not mint a per-repo key. Committed OmniAuth values are placeholders; put real Google (or other) secrets locally with `credentials:edit`. If the master key is missing, dummy still boots with those same placeholders so Devise OmniAuth callbacks load (Google in development, all five providers in test). Deep-link OTP lives on `/users/sign_in/otp` and `/users/sign_up/otp`. Dummy does not copy or override core's default layout. Core 6.1 puts `data-theme="rounded"` on `html`. Dummy's `recording_studio/_default_layout_head` repeats that attribute so primary buttons inherit charcoal, not `:root` blue. Dummy pins Flatpack `v0.2.0`.

Dummy also installs released `recording_studio_terms_and_conditions` `v0.22.0` (Publishable `v1.5.0`) as an end-to-end signup demo. That pin lives in `test/dummy/Gemfile` only. The Users gemspec and root Gemfile stay free of TnC. The path gem satisfies TnC’s `recording_studio_user >= 0.30.0` requirement. Dummy seeds one live Terms record under **My workspace**. Dummy sets `signup_notice_partials` to its own partial (`By continuing you agree to the Terms`) and accepts pending terms from `after_registration`. The same dummy Gemfile pins `recording_studio_root_switchable` `v0.17.0` for the top-nav switcher (switch rate limit via RecordingStudioCache; no host code change). Root and dummy pin Recording Studio core `v7.8.0` (English fallback for shipped `recording_studio.*` keys via `RecordingStudio.t`).

Profile show/edit are that chrome only — no sidebar, Sign out, Root Switchable, or Access slot. Show is Avatar plus Edit at `:xl`. Edit hosts `#profile-photo` with `FlatPack::ImageInput::Component` at `:"2xl"` (FlatPack `0.1.329`). Dummy still mounts Attachable and keeps a leftover attachment-show override (one core PageNav) if that URL is opened directly. Seeded accounts include:

| Email | Password |
| --- | --- |
| `admin@admin.com` | `Password123!` |
| `member@admin.com` | `Password123!` |
| `otp@admin.com` | none — signs in with an email code |

Seeded users get Profile snapshots under the shared People root, with Accessible `:admin` on each Profile recording. Avery Admin also gets a real image on that Profile recording. Dummy mounts notifications at `/notifications` (inbox and settings), email as a delivery channel, and push at `/notifications/push`. The dummy Gemfile pins released `recording_studio_notifications` `v0.21.0`, `recording_studio_notifications_email` `v0.5.4`, and `recording_studio_notifications_push` `v0.10.0` (github tags). Dummy pins `recording_studio_api` `v1.21.2`, Metrics `v0.10.0`, and Trashable `v1.3.0` (`require: false` for the last two). Dummy also pins `recording_studio_mcp` `v0.35.0` and `recording_studio_oauth` `v0.25.0`. Site settings is tag `v0.6.0`. Dummy Cache is `v0.8.0`. The Users gemspec does not depend on MCP or Oauth. Workspace remains the host-owned bucket.

## Cloud Agent boot

Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
The install hook provisions a cold image. On a warm snapshot it skips apt,
ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
already usable. If `RAILS_MASTER_KEY` is set, `install.sh` writes the
gitignored dummy credential key files so credentials decrypt. Fetch-skills
always runs last. `.cursor/start.sh` starts PostgreSQL on each boot. Rebuild
with Draft off to load a new pack. See
[Cursor skills in Cloud Agents](docs/cursor-skills.md).

## Development

Run the standard validation from the repository root:

```bash
bundle exec rake test
bundle exec rake test:all
```

The dummy app's CI entrypoint is its lint and security workflow:

```bash
cd test/dummy
bin/ci
```
