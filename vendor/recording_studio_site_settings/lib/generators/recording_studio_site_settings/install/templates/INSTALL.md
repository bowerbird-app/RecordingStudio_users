RecordingStudioSiteSettings install complete.

Next steps:

1. Review config/initializers/recording_studio_site_settings.rb and set site_root_types.
2. Install the engine migrations with `bin/rails generate recording_studio_site_settings:migrations`.
3. Apply the migrations with `bin/rails db:migrate`.
4. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
5. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
6. Keep strict recordable declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.
