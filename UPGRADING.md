# Upgrading

## 0.26.0

Bump to `0.26.0`. No Users migration.

Require Recording Studio >= 6.1.0, FlatPack >= 0.1.320, and ViewComponent >= 4.14, < 5. Pin the host Gemfile to Recording Studio `v6.1.0`. FlatPack `0.1.324` is commit `d005941bf5a09a51582d5b7418fe5486738474eb`. `FlatPack::ImageInput::Component` shipped in 0.1.320.

Edit Profile draws that component at `size: :"2xl"` and `shape: :circle`. The form direct-uploads through Attachable, then **Update profile** calls `assign_profile_image!(user, signed_blob_id:, actor:)`. Clearing a saved photo posts `profile_image[remove]=1` and calls `remove_profile_image!`. The submit row uses `pt-4`.

`RecordingStudioUser.configuration.layout` defaults to `nil`. `nil` uses `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`. A String names a layout. `false` renders with no layout. A callable must be `call(controller:)` and return one of those values. Invalid values raise `ArgumentError` at assignment.

Signed-in Users controllers call `recording_studio_layout`. Do not set `layout "recording_studio/default_layout"` on those controllers. Sign-in, sign-up, password reset, and confirmation stay on `layouts/recording_studio_user/auth`.

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
