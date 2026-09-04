# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-02

### Added
- Site name, square logo, wide logo, and optional favicon as this gem's source of truth. One set per site root.
- Public read API: `name_for`, `square_logo_for`, `wide_logo_for`, `logo_for`, `favicon_for`, `recording_studio_site_square_logo`, `recording_studio_site_wide_logo`, `recording_studio_site_logo`, and `recording_studio_site_favicon`.
- Public write API: `update!`, gated with Accessible `:edit` on the site root. `square_logo_io` and `wide_logo_io` attach the marks. `logo_io` writes the square slot. `favicon_io` attaches the tab icon.
- Logo and favicon storage through three Attachable image children on this gem's site-settings recording, not on the root, named `square_logo`, `wide_logo`, and `favicon`.
- One Admin section and one screen for staff to edit name, both logos, and the tab icon.
- Dummy host that seeds a named Admin site with both logos, a named empty-mark Empty Admin root, Studio and Client Studio workspaces without site settings, and a 403 actor. Dummy sets `site_root_types` to `AdminRoot`. The gem default for hosts stays `Workspace`. Dummy layout head prints the favicon link tag from the Admin site root. Dummy home and dummy docs print the wide logo in a Flatpack Sidebar from that same Admin site root. Dummy does not override core `default_layout`.

### Changed
- Admin PageNav is the back control only. The visible title is PageTitle once.
- Admin form spacing comes from Flatpack Grid. Fields stack in this order: site name, wide logo, square logo, favicon. Save and Cancel are separate Buttons after the fields.
- Mark rows stack full width. Square logo uses Attachable's file button and a square Avatar. Wide logo uses the same button and the image in real proportion. Empty Avatars pass Flatpack `icon: "photo"`. Name save is a separate form. The page does not use Flatpack FileInput.
- `SiteSetting` allowed parents follow live `site_root_types`. Dummy parents site settings on `AdminRoot` so Accessible `:edit` on that root covers writes. Hosts still default to `Workspace`.
- Dummy and the README GitHub tag track Accessible `v0.9.0`. The gemspec floor stays `~> 0.8`.
- Dummy Tailwind writes resolved gem `@source` paths before each build so core PageNav back keeps its Flatpack icon size.
- Flatpack floor is `>= 0.1.144` so empty Avatars can pass `icon: "photo"`.

### Upgrade notes
- Add `recording_studio_site_settings` `~> 0.1`.
- Pin `recording_studio ~> 4.2`, Accessible `~> 0.8`, Admin `~> 2.0`, Attachable `~> 0.5`, and Flatpack `>= 0.1.144`.
- Register `RecordingStudioSiteSettings::SiteSetting` and `RecordingStudioAttachable::Attachment`.
- Do not add name, logo, or favicon columns to core or to the root recordable.
- Read name, logos, and favicon from this gem. Do not read Attachable to print a site mark.
- Print the square mark with `recording_studio_site_square_logo` or `recording_studio_site_logo`. Print the wide mark with `recording_studio_site_wide_logo`. Print the tab icon with `recording_studio_site_favicon`. Do not depend on Attachable from other gems just for those marks.
- Set `site_root_types` in the initializer. Do not add a YAML settings file.

[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_site_settings/releases/tag/v0.1.0
