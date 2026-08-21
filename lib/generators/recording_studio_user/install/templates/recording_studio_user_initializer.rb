# frozen_string_literal: true

# Route configuration must load before Rails draws routes.
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.mount_path = "/recording_studio_users"
  config.profile_route_path = "profile"
  config.admin_route_path = "admin"
  config.layout = "application"
  config.additional_profile_attributes = []
end

# Register RecordingStudioUser::People and RecordingStudioUser::Profile in
# RecordingStudio.configure { |c| c.recordable_types = [...] }, then run:
#   bin/rails generate recording_studio_user:migrations
#   bin/rails db:migrate
