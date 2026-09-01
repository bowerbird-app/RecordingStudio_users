# frozen_string_literal: true

module RecordingStudioUser
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioUser

    config.before_initialize do
      RecordingStudioUser.config.validate!
    end

    initializer "recording_studio_user.profiled_user" do
      config.to_prepare do
        user_class = RecordingStudioUser.config.user_class
        user_class.include RecordingStudioUser::ProfiledUser unless user_class < RecordingStudioUser::ProfiledUser

        next unless RecordingStudioUser.config.otp_enabled?

        OtpSetup.ensure_notifications!
        unless user_class.devise_modules.include?(:confirmable)
          user_class.devise :confirmable
        end
        OtpNotifications.register!
      end
    end

    initializer "recording_studio_user.admin_definitions" do
      config.to_prepare { RecordingStudioUser::Admin.register! }
    end

    initializer "recording_studio_user.filter_parameters" do |app|
      app.config.filter_parameters += %i[otp code login_code]
    end
  end
end
