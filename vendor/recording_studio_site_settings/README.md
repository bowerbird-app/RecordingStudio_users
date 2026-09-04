# Recording Studio Site Settings

This gem is the source of truth for a site's name, square logo, wide logo, and tab icon in Recording Studio.

Core does not store them. The site root does not store them. Other gems read them from this gem. Do not call Attachable just to print a mark.

Each site root gets one name, one square logo, one wide logo, and one optional favicon. Name lives on this gem's site-settings recording. The three images are Attachable children under that recording, named `square_logo`, `wide_logo`, and `favicon`.

`logo_for` and `recording_studio_site_logo` are aliases for the square mark. There is no third logo upload.

## Install

Add the gem and its Recording Studio majors:

```ruby
gem "recording_studio_site_settings"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.0"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "2.0.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.0"
```

Then:

```bash
bin/rails generate recording_studio_site_settings:install
bin/rails generate recording_studio_site_settings:migrations
bin/rails generate recording_studio_attachable:install
bin/rails generate recording_studio_attachable:migrations
bin/rails db:migrate
```

Register this gem's type next to the host root and Attachable's attachment type:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "RecordingStudioSiteSettings::SiteSetting",
    "RecordingStudioAttachable::Attachment"
  ]
end
```

Tell the gem which recordable is a site root. Site settings may sit under those types. Allowed parents follow this list after you set it, not a snapshot from class load.

```ruby
RecordingStudioSiteSettings.configure do |config|
  config.site_root_types = ["Workspace"]
end
```

Enable Accessible on the site root and on the admin root. Enable Attachable only on `RecordingStudioSiteSettings::SiteSetting`. Do not enable Attachable on the root to hold the marks.

Mount the engines and Admin:

```ruby
mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
mount RecordingStudioSiteSettings::Engine, at: "/recording_studio_site_settings"
recording_studio_admin_for :admin, at: "/admin", root_section: :site_settings
```

Enable the `site_settings` section on the admin root. Grant Accessible access on that admin root. People without that grant get 403.

## Read name, logos, and favicon

```ruby
root = RecordingStudio.root_recording_for(workspace)

RecordingStudioSiteSettings.name_for(root)
RecordingStudioSiteSettings.square_logo_for(root)
RecordingStudioSiteSettings.square_logo_for(root).preview_url
RecordingStudioSiteSettings.square_logo_for(root).present?
RecordingStudioSiteSettings.wide_logo_for(root)
RecordingStudioSiteSettings.wide_logo_for(root).present?
RecordingStudioSiteSettings.logo_for(root)
RecordingStudioSiteSettings.favicon_for(root)
RecordingStudioSiteSettings.favicon_for(root).present?
```

In a view:

```erb
<%= RecordingStudioSiteSettings.name_for(current_root_recording) %>
<%= recording_studio_site_square_logo(current_root_recording) %>
<%= recording_studio_site_wide_logo(current_root_recording) %>
<%= recording_studio_site_logo(current_root_recording) %>
<%= recording_studio_site_favicon(current_root_recording) %>
```

`square_logo_for`, `wide_logo_for`, `logo_for`, and `favicon_for` return a small object with `recording`, `preview_url`, `filename`, `present?`, and `blank?`. Callers should not reach into Attachable to render the mark.

`recording_studio_site_square_logo` prints a square Avatar when a square mark is present, or nothing. `recording_studio_site_wide_logo` prints the wide image in its real proportion when present, or nothing. `recording_studio_site_favicon` returns a `<link rel="icon">` tag when a tab icon is present, or nothing. Put the favicon helper in the layout head. Favicon is optional. This gem does not convert to `.ico` or crop the file.

## Write name, logos, and favicon

```ruby
RecordingStudioSiteSettings.update!(
  root,
  name: "Studio",
  actor: current_user,
  square_logo_io: File.open("square-logo.png"),
  square_logo_filename: "square-logo.png",
  square_logo_content_type: "image/png",
  wide_logo_io: File.open("wide-logo.png"),
  wide_logo_filename: "wide-logo.png",
  wide_logo_content_type: "image/png",
  favicon_io: File.open("favicon.png"),
  favicon_filename: "favicon.png",
  favicon_content_type: "image/png"
)
```

Writes check Accessible `:edit` on the site root. Name changes `revise` the site-settings recording. A second file for the same slot replaces the file on that attachment. Square, wide, and favicon stay separate children.

`logo_io` still writes the square slot.

## Admin

Staff open one Admin section, Site, and one screen that edits name, both logos, and the tab icon. The screen uses Recording Studio core default layout. Call `recording_studio_page_nav` so PageNav back is on the page. Back is `history.back()`. The title lives once in PageTitle.

Rows stack full width, one field per row. Site name first, then wide logo, then square logo, then favicon. Square logo is a square Avatar at size `2xl` plus Attachable Add or Change. Wide logo shows the image in real proportion, or a photo icon when empty, plus the same Add or Change control. Favicon uses a smaller square Avatar. Empty square, wide, and favicon Avatars pass Flatpack `icon: "photo"`, so the empty slot is a photo, not a person. Filled square and favicon slots still show the attached image. Save and Cancel sit after the fields as separate Buttons. Name has its own Save. Cancel goes back. Accessible on the admin root gates the page. `user.admin?` is not used. Hosts need Flatpack `0.1.144` or newer for that empty icon.

## Dummy app

`test/dummy` is a host that proves this gem. Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. The admin screen is `/recording_studio_site_settings/settings`.

Dummy Tailwind writes resolved engine `@source` paths to `gem_sources.css` before each build. Bundle globs miss Flatpack on some install paths, and without those component classes PageNav back collapses to 2px.

The dummy layout head prints `recording_studio_site_favicon` from dummy's Admin site root. Dummy does not override Recording Studio core `default_layout`. Dummy home and dummy docs print `recording_studio_site_wide_logo` in a Flatpack Sidebar so hosts can see that helper work. The site settings admin screen does not.

Dummy sets `site_root_types` to `AdminRoot` so we can prove Accessible inheritance from the admin root. The gem default for hosts stays `Workspace`. Site settings is a child of that Admin root. Dummy does not enable `:accessible` on Site settings. Grants stay on the admin root.

## What dummy seeds

- Admin: name, square logo, and wide logo. No favicon.
- Empty Admin: name only. All three image slots empty.
- Studio and Client Studio workspaces. No site settings under either workspace.
- `member@admin.com` can sign in and gets 403 on the admin screen.
