# frozen_string_literal: true

module RecordingStudioUser
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioUser

    initializer "recording_studio_user.profiled_user" do
      config.to_prepare do
        user_class = RecordingStudioUser.config.user_class
        user_class.include RecordingStudioUser::ProfiledUser unless user_class < RecordingStudioUser::ProfiledUser
      end
    end

    initializer "recording_studio_user.admin_definitions" do
      config.to_prepare { RecordingStudioUser::Admin.register! }
    end
  end
end
