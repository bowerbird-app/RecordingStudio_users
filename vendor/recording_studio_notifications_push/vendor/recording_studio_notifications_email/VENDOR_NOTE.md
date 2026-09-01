# Temporary vendor

Forked from https://github.com/bowerbird-app/RecordingStudio_notifications_email
for Recording Studio 4.2 compatibility while upstream still pins `recording_studio < 4`.

Gemspec changes only:
- `recording_studio ~> 4.2`
- `recording_studio_notifications >= 0.2, < 1`

Delete this directory once upstream publishes a compatible gemspec and point
Gemfiles back at GitHub `main`.
