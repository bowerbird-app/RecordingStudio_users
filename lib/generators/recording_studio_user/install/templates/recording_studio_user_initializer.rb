# frozen_string_literal: true

RecordingStudioUser.configure do |config|
  # The default model is owned by the gem and uses the host application's users table.
  config.user_model = "RecordingStudioUser::User"

  # Change the URL without changing the public profile_path/edit_profile_path helpers.
  config.profile_path = "<%= options[:profile_path] %>"

  # Authentication and profile pages use the host application's normal layout.
  config.default_layout = "application"

  # Keep this empty unless the compatible user model and profile UI support extra fields.
  config.additional_permitted_profile_attributes = []

  # Definitions register automatically without changing RecordingStudioAdmin access settings.
  config.admin_registration_hook = -> { RecordingStudioUser.register_admin! }
end
