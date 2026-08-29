# frozen_string_literal: true

module RecordingStudioUser
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioUser

    initializer "recording_studio_user.omniauth", after: :load_config_initializers do
      RecordingStudioUser::Omniauth.register_providers!
    end

    initializer "recording_studio_user.helpers" do
      ActiveSupport.on_load(:action_controller) do
        helper RecordingStudioUser::OmniauthHelper if respond_to?(:helper)
      end
      ActiveSupport.on_load(:action_view) do
        include RecordingStudioUser::OmniauthHelper
      end
    end

    # Include ProfiledUser and :omniauthable before routes draw so devise_for
    # emits OmniAuth callback routes when providers are configured.
    initializer "recording_studio_user.profiled_user", before: :set_routes_reloader_hook do
      RecordingStudioUser::Engine.apply_profiled_user!
    end

    initializer "recording_studio_user.profiled_user_reload" do
      config.to_prepare { RecordingStudioUser::Engine.apply_profiled_user! }
    end

    initializer "recording_studio_user.admin_definitions" do
      config.to_prepare { RecordingStudioUser::Admin.register! }
    end

    def self.apply_profiled_user!
      user_class = RecordingStudioUser.config.user_class
      user_class.include RecordingStudioUser::ProfiledUser unless user_class < RecordingStudioUser::ProfiledUser
      RecordingStudioUser::Omniauth.ensure_omniauthable!(user_class)
    rescue ArgumentError
      # Host user class may not be loadable during early boot in some hosts.
    end
  end
end
