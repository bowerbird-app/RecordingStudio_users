# frozen_string_literal: true

RecordingStudioUser.configure do |config|
  config.user_model = "RecordingStudioUser::User"
  config.profile_path = "profile"
  config.default_layout = "flat_pack_sidebar"
  config.additional_permitted_profile_attributes = []
  config.admin_registration_hook = -> { RecordingStudioUser.register_admin! }
end
