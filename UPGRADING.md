# Upgrading

## Unreleased

## 0.27.3

Bump to `0.27.3`. No Users migration.

Operations list users (`GET` users) now declares `page` and `per_page` on
the endpoint `input_contract`. MCP and OpenAPI show those optional integers.
Paging behavior is unchanged (default 50, max 100). Extra keys return `422`.

## 0.27.2

Bump to `0.27.2`. No Users migration.

Operations OTP create (`POST` users with no password) now applies
profile fields with `record_profile!`. `create_unconfirmed_user!` is
unchanged. Email-only OTP create still records no Profile.

## 0.27.1

Bump to `0.27.1`. No Users migration.

Password sign-in, password reset, and OTP login requests show the same
message for an unknown address, a password account, and an OTP-only account.
This is not timing-equivalent: password sign-in still runs bcrypt only for
existing password accounts. Sign-in always uses
`email_or_password_mismatch`. Reset uses Devise's send-instructions notice
(or the paranoid notice when `Devise.paranoid` is true) and does not email
OTP-only or unknown addresses. Password sign-up with an existing email uses
`signup_did_not_save` instead of `email_taken`; it still returns an error for
that address. New password accounts still sign in immediately, so this is
not a fully silent confirmable flow.

OmniAuth sign-in now rotates the session before `sign_in`, matching password
and OTP. `otp_account_password`, `otp_account_reset`, and `email_taken`
remain as unused public keys. This release does not add lockout or
rate limiting for password sign-in.

Development pins: Accessible `v0.24.1`, Logs `v0.7.3`, Trashable `v0.12.2`,
dummy Root Switchable `v0.11.4`. Admin, dummy Cache, dummy API, and
`view_component` stay put.

## 0.27.0

Bump to `0.27.0`. No Users migration.

Signed-out auth screens (sign in, sign up, password reset, resend
confirmation, and OTP steps) use `recording_studio_layout` like the rest of
Users. They no longer ship `layouts/recording_studio_user/auth`. The
`_shell` partial is an in-page content wrapper on Default Layout: centered
`max-w-sm` column, site logo above a centered heading, no Back/Close
chevrons on those screens.

Delete a host copy of `app/views/layouts/recording_studio_user/auth.html.erb`
if you only kept it for centering. Do not copy `_shell` unless you are
replacing the in-page wrapper. Set `RecordingStudioUser.configuration.layout`
or `RecordingStudio.configure { |c| c.layout = ... }` when the host layout
should differ from `RecordingStudio::DEFAULT_LAYOUT`. Confirmations and
passwords inherit from Devise, so they call `recording_studio_layout` on
those controllers. Do not add `layout "recording_studio/default_layout"`.

`config.auth_body_start_partial` and `content_for :recording_studio_user_auth_body_start`
still render, now at the start of the page body inside the default layout,
not as the first child of `<body>`. Flash notice and alert come from the
default layout. Auth views no longer paint those alerts themselves.

Auth screens do not set `content_for :title`, so Default Layout does not
draw a second heading above the logo. The visible heading is `PageTitle`
`variant: :h2` in `_shell`. The document title is set from `:head`.

## 0.26.6

Bump to `0.26.6`. No Users migration.

This is a public gemspec change. `recording_studio_cache` is now
`>= 0.5, < 1`. Hosts can resolve Cache 0.6.x, which needs Recording
Studio 6.1+. Development pins Recording Studio `v6.3.0`, FlatPack
`v0.1.341`, Accessible `v0.24.0`, root Cache `v0.6.2`, Logs `v0.7.2`,
Metrics `v0.7.2`. Admin stays `v2.7.0`. Dummy stays on Cache `v0.5.1`
and Site Settings `v0.2.1`. Dummy also pins Notifications `v0.14.7`,
Notifications Email `v0.5.1`, TnC `v0.14.2`, Publishable `v0.13.0`,
Root Switchable `v0.11.3`, API `v0.17.1`, Oauth `v0.21.0`, MCP
`v0.23.2`. API `v0.18.1` does not resolve with Oauth or MCP. Hosts that
copy dummy Notifications schema need the inbox column and the email
suppressions table. Root Switchable 0.11+ rejects `:application_layout`;
dummy sets `layout` to `"recording_studio/default_layout"`.

## 0.26.5

Bump to `0.26.5`. No Users migration.

This release only refreshes development pins: root Gemfile Recording Studio
`v6.3.0` and Cache `v0.6.0`. Dummy stays on core `v6.1.0` and Cache
`v0.5.1`. FlatPack stays on `v0.1.329`. The public
`recording_studio_cache` requirement is unchanged (`~> 0.5`).

## 0.26.4

Bump to `0.26.4`. No Users migration.

Hosts must stay on FlatPack >= 0.1.328. Dummy and development Gemfiles pin
tag `v0.1.329`. Continue-with provider logos still pass a trusted inline SVG
string on `FlatPack::Button` `icon:`. Users does not prepend Button.

## 0.26.3

Bump to `0.26.3`. No Users migration.

Hosts must be on FlatPack >= 0.1.328. That release accepts a trusted
inline SVG string on `FlatPack::Button` `icon:` (starts with `<svg`),
sized like a Heroicon. Users no longer prepends Button for Continue-with
provider logos. Pin the host Gemfile to FlatPack commit
`d1206e7c515bff9c25c01a2f5c6399d208ba667e` (version 0.1.328) or a later
tag that includes it.

## 0.26.2

Bump to `0.26.2`. No Users migration. No host code changes.

`replace_profile_image!` authorizes Attachable `:upload` when it issues a
replacement blob (`ProfileImage::Blobs`). Edit Profile does not also call
`authorize_provider_upload!`. `create_user!` still bootstraps `:admin` on
the owner's Profile, which includes upload. An actor without an access row
on that Profile is forbidden.

Auth footers, profile identity, and sign-in method labels use Flatpack
components. The OTP code page still draws the code in large monospace,
select-all text. Override those views if you copied the old markup.

## 0.26.1

Bump to `0.26.1`. No Users migration. No host code changes.

The packaged gem no longer includes leftover gem-template generator files or
the example `gem_template_pages` migration.

## 0.26.0

Bump to `0.26.0`. No Users migration.

Require Recording Studio >= 6.1.0, FlatPack >= 0.1.320, and ViewComponent >= 4.14, < 5. Pin the host Gemfile to Recording Studio `v6.1.0`. FlatPack `0.1.324` is commit `d005941bf5a09a51582d5b7418fe5486738474eb`. `FlatPack::ImageInput::Component` shipped in 0.1.320.

Edit Profile draws that component at `size: :"2xl"` and `shape: :circle`. The form direct-uploads through Attachable, then **Update profile** calls `assign_profile_image!(user, signed_blob_id:, actor:)`. Clearing a saved photo posts `profile_image[remove]=1` and calls `remove_profile_image!`. The submit row uses `pt-4`.

`RecordingStudioUser.configuration.layout` defaults to `nil`. `nil` uses `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`. A String names a layout. `false` renders with no layout. A callable must be `call(controller:)` and return one of those values. Invalid values raise `ArgumentError` at assignment.

Users controllers call `recording_studio_layout`. Do not set `layout "recording_studio/default_layout"` on those controllers. Signed-out auth screens use the same resolver. See **Unreleased**.

On profile show, profile edit, the OTP code page, and sign-in methods:

1. Set `content_for :title`. Set `content_for :subtitle` only when the page has one.
2. Call `flat_pack_page_nav(round: true, style: :default, back_href:, back_tooltip:, anchor_href:, anchor_tooltip:)` for Back and Close.
3. Call `register_page_nav("Label", path, role: :primary)` for right-hand actions. `role` is `:primary`, `:secondary`, or `:destructive`.
4. Pass `shadow: :md` on cards that used to pass `style: :elevated`.

The default layout draws one `<h1>` from `:title`. Do not also render `FlatPack::PageTitle` in the view body.

Load `flat_pack/variables`, `flat_pack/application`, and `flat_pack/rich_text` before the Tailwind stylesheet.

Drop `RecordingStudioAttachable::Library` and `RecordingStudioAttachable::Placement` from `config.recordable_types`. Attachable 0.22 declares `RecordingStudioAttachable::Attachment` only.

If a sibling engine still `include`s `RecordingStudio::UsesDefaultLayout`, define that module in a host initializer before the engine boots. The module sets `layout "recording_studio/default_layout"` and includes `RecordingStudio::LayoutHelper`.

Notifications `0.7` and Root Switchable `0.9` still pass removed FlatPack keywords (`anchor_href`, `anchor_label`, `style:` on cards). The dummy translates those in `test/dummy/config/initializers/flat_pack_legacy_components.rb` until those gems move to `flat_pack_page_nav` and `background` / `border` / `shadow`.

## 0.25.1

Bump to `0.25.1`. No migration.

To render the same partial at the start of every unsigned auth `<body>` (sign in, sign up, and the rest) without copying the layout or overriding `auth_site_logo`:

```ruby
config.auth_body_start_partial = "shared/views_tracking"
```

Leave it unset (`nil`) and the auth HTML stays as in `0.25.0`. If a view already filled `content_for :recording_studio_user_auth_body_start`, that markup wins and the partial is not rendered.
