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
      ].each do |name|
        require engine_root.join("app/helpers/recording_studio_user/#{name}").to_s
      end
    end

    def apply_profiled_user!
      require_dependency engine_root.join(
        "app/models/concerns/recording_studio_user/profiled_user.rb"
      ).to_s
      user_class = load_user_class
      user_class.include RecordingStudioUser::ProfiledUser unless user_class < RecordingStudioUser::ProfiledUser
      RecordingStudioUser::Omniauth.ensure_omniauthable!(user_class)
      apply_devise_confirmable!(user_class)
      apply_otp_setup!(user_class)
    rescue ArgumentError
      # Host user class may not be loadable during early boot in some hosts.
    end

    def apply_devise_confirmable!(user_class)
      user_class.devise :confirmable unless user_class.devise_modules.include?(:confirmable)
      return if user_class.ancestors.include?(PasswordConfirmation::Confirms)

      user_class.prepend PasswordConfirmation::Confirms
    end

    def apply_otp_setup!(user_class)
      apply_confirmation_code_setup! if OtpSetup.codes_required?
      return unless RecordingStudioUser.config.otp_enabled?

      apply_devise_confirmable!(user_class)
    end

    def apply_confirmation_code_setup!
      OtpSetup.ensure_notifications!
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
