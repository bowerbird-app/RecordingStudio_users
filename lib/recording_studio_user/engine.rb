# frozen_string_literal: true

module RecordingStudioUser
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioUser

    config.before_initialize do
      RecordingStudioUser.config.validate!
    end

    initializer "recording_studio_user.omniauth", after: :load_config_initializers do
      RecordingStudioUser::Omniauth.register_providers!
    end

    rake_tasks do
      load RecordingStudioUser::Engine.root.join("lib/tasks/recording_studio_user_identities.rake")
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

    initializer "recording_studio_user.filter_parameters" do |app|
      app.config.filter_parameters += %i[otp code login_code]
    end

    # Flatpack Button `icon:` is Heroicon-only; List::Item already accepts inline SVG.
    # Continue-with provider logos need the same SVG branch on Button.
    initializer "recording_studio_user.flatpack_button_svg_icon" do
      config.to_prepare { RecordingStudioUser::Engine.apply_flatpack_button_svg_icon! }
    end

    def self.apply_flatpack_button_svg_icon!
      require "recording_studio_user/flatpack_button_svg_icon"
      return unless defined?(FlatPack::Button::Component)
      return if FlatPack::Button::Component.ancestors.include?(RecordingStudioUser::FlatpackButtonSvgIcon)

      FlatPack::Button::Component.prepend(RecordingStudioUser::FlatpackButtonSvgIcon)
    end

    def self.apply_profiled_user!
      require_dependency root.join(
        "app/models/concerns/recording_studio_user/profiled_user.rb"
      ).to_s
      user_class = load_user_class
      user_class.include RecordingStudioUser::ProfiledUser unless user_class < RecordingStudioUser::ProfiledUser
      RecordingStudioUser::Omniauth.ensure_omniauthable!(user_class)
      apply_otp_setup!(user_class)
    rescue ArgumentError
      # Host user class may not be loadable during early boot in some hosts.
    end

    def self.apply_otp_setup!(user_class)
      return unless RecordingStudioUser.config.otp_enabled?

      OtpSetup.ensure_notifications!
      user_class.devise :confirmable unless user_class.devise_modules.include?(:confirmable)
      OtpNotifications.register!
      OtpSetup.validate_schema_when_ready!
    end

    def self.load_user_class
      application_record_path = Rails.root.join("app/models/application_record.rb")
      require_dependency application_record_path.to_s if application_record_path.exist?

      model_path = Rails.root.join(
        "app/models",
        "#{RecordingStudioUser.config.user_class_name.underscore}.rb"
      )
      require_dependency model_path.to_s if model_path.exist?
      RecordingStudioUser.config.user_class
    end
  end
end
