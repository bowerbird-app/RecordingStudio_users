# frozen_string_literal: true

module RecordingStudioUser
  # Boot helpers kept off Engine so Metrics/ClassLength can apply to the engine class.
  module EngineBoot
    module_function

    def load_view_helpers!
      %w[
        omniauth_helper
        auth_routes_helper
        auth_site_logo_helper
        auth_terms_notice_helper
      ].each do |name|
        require engine_root.join("app/helpers/recording_studio_user/#{name}").to_s
      end
    end

    def prefer_signup_view_paths!
      return unless defined?(ActionController::Base)
      return unless defined?(Rails.root)

      users_views = engine_root.join("app/views").to_s
      host_views = Rails.root.join("app/views").to_s
      paths = ActionController::Base.view_paths.map(&:to_s)
      return if paths[0] == host_views && paths[1] == users_views

      # Users before TnC/Devise; host before Users.
      ActionController::Base.prepend_view_path(users_views)
      ActionController::Base.prepend_view_path(host_views)
    end

    def apply_flatpack_button_svg_icon!
      require "recording_studio_user/flatpack_button_svg_icon"
      return unless defined?(FlatPack::Button::Component)
      return if FlatPack::Button::Component.ancestors.include?(RecordingStudioUser::FlatpackButtonSvgIcon)

      FlatPack::Button::Component.prepend(RecordingStudioUser::FlatpackButtonSvgIcon)
    end

    def apply_profiled_user!
      require_dependency engine_root.join(
        "app/models/concerns/recording_studio_user/profiled_user.rb"
      ).to_s
      user_class = load_user_class
      user_class.include RecordingStudioUser::ProfiledUser unless user_class < RecordingStudioUser::ProfiledUser
      RecordingStudioUser::Omniauth.ensure_omniauthable!(user_class)
      apply_otp_setup!(user_class)
    rescue ArgumentError
      # Host user class may not be loadable during early boot in some hosts.
    end

    def apply_otp_setup!(user_class)
      return unless RecordingStudioUser.config.otp_enabled?

      OtpSetup.ensure_notifications!
      user_class.devise :confirmable unless user_class.devise_modules.include?(:confirmable)
      OtpNotifications.register!
      OtpSetup.validate_schema_when_ready!
    end

    def load_user_class
      application_record_path = Rails.root.join("app/models/application_record.rb")
      require_dependency application_record_path.to_s if application_record_path.exist?

      model_path = Rails.root.join(
        "app/models",
        "#{RecordingStudioUser.config.user_class_name.underscore}.rb"
      )
      require_dependency model_path.to_s if model_path.exist?
      RecordingStudioUser.config.user_class
    end

    def engine_root
      RecordingStudioUser::Engine.root
    end
  end
end
