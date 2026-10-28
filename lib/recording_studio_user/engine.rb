# frozen_string_literal: true

require "recording_studio_user/engine_boot"

module RecordingStudioUser
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioUser

    config.before_initialize do
      RecordingStudioUser.config.validate!
    end

    initializer "recording_studio_user.helpers", after: :set_autoload_paths do
      RecordingStudioUser::EngineBoot.load_view_helpers!
      ActiveSupport.on_load(:action_controller) do
        helper RecordingStudioUser::OmniauthHelper if respond_to?(:helper)
        helper RecordingStudioUser::AuthRoutesHelper if respond_to?(:helper)
        helper RecordingStudioUser::AuthSiteLogoHelper if respond_to?(:helper)
        helper RecordingStudioUser::AuthTermsNoticeHelper if respond_to?(:helper)
      end
      ActiveSupport.on_load(:action_view) do
        include RecordingStudioUser::OmniauthHelper
        include RecordingStudioUser::AuthRoutesHelper
        include RecordingStudioUser::AuthSiteLogoHelper
        include RecordingStudioUser::AuthTermsNoticeHelper
      end
    end

    initializer "recording_studio_user.omniauth", after: :load_config_initializers do
      RecordingStudioUser::Omniauth.register_providers!
    end

    config.after_initialize do
      require "omniauth/rails_csrf_protection"
      OmniAuth.config.request_validation_phase = OmniAuth::RailsCsrfProtection::TokenVerifier.new
      RecordingStudioUser::Services::OtpRateLimiter.warn_unless_shared_store!
    end

    rake_tasks do
      load RecordingStudioUser::Engine.root.join("lib/tasks/recording_studio_user_identities.rake")
    end

    # Include ProfiledUser and :omniauthable before routes draw so devise_for
    # emits OmniAuth callback routes when providers are configured.
    initializer "recording_studio_user.profiled_user", before: :set_routes_reloader_hook do
      RecordingStudioUser::EngineBoot.apply_profiled_user!
    end

    initializer "recording_studio_user.profiled_user_reload" do
      config.to_prepare { RecordingStudioUser::EngineBoot.apply_profiled_user! }
    end

    initializer "recording_studio_user.admin_definitions" do
      config.to_prepare { RecordingStudioUser::Admin.register! }
    end

    initializer "recording_studio_user.api" do
      config.to_prepare { RecordingStudioUser::Api.register! }
    end

    initializer "recording_studio_user.metrics" do
      config.to_prepare { RecordingStudioUser::Metrics.register! }
    end

    # TnC prepends its registrations/extra_fields override onto ActionController::Base.
    # Re-assert Users after TnC so soft-detect wins over TnC's hard partial,
    # then put the host app/views in front so hosts override either gem —
    # normal Rails precedence (host > this gem > TnC/Devise).
    initializer "recording_studio_user.signup_view_path" do
      ActiveSupport.on_load(:action_controller_base) do
        RecordingStudioUser::EngineBoot.prefer_signup_view_paths!
      end
      config.to_prepare { RecordingStudioUser::EngineBoot.prefer_signup_view_paths! }
    end

    initializer "recording_studio_user.filter_parameters" do |app|
      app.config.filter_parameters += %i[otp code login_code]
    end

    def self.load_view_helpers! = EngineBoot.load_view_helpers!
    def self.prefer_signup_view_paths! = EngineBoot.prefer_signup_view_paths!
    def self.apply_profiled_user! = EngineBoot.apply_profiled_user!
    def self.apply_otp_setup!(user_class) = EngineBoot.apply_otp_setup!(user_class)
    def self.load_user_class = EngineBoot.load_user_class
  end
end
