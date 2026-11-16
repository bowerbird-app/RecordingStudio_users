# frozen_string_literal: true

module RecordingStudioUser
  module OtpSetup
    module_function

    REQUIRED_USER_COLUMNS = %w[
      registered_with confirmation_token confirmed_at confirmation_sent_at unconfirmed_email
    ].freeze
    OTP_CHALLENGES_TABLE = "recording_studio_user_otp_challenges"

    def validate_schema!
      missing = missing_schema
      return if missing.empty?

      raise(
        ArgumentError,
        "Email codes need schema that is missing: #{missing.join(', ')}. " \
        "Run `rails generate recording_studio_user:migrations` and migrate."
      )
    end

    def missing_schema
      user_class = RecordingStudioUser.config.user_class
      table = user_class.table_name
      columns = user_class.connection.columns(table).map(&:name)

      missing = (REQUIRED_USER_COLUMNS - columns).map { |column| "#{column} on #{table}" }
      missing << "#{OTP_CHALLENGES_TABLE} table" unless user_class.connection.data_source_exists?(OTP_CHALLENGES_TABLE)
      missing
    end

    def ensure_notifications!
      return if defined?(RecordingStudioNotifications)

      raise ArgumentError,
            "Email codes need recording_studio_notifications. Add the gem and run its install generator."
    end

    def ensure_confirmation_codes!
      ensure_notifications!
      validate_schema!
    end

    def codes_required?
      config = RecordingStudioUser.config
      config.otp_enabled? || config.password_registration_allowed?
    end

    def validate_schema_when_ready!
      return unless codes_required?

      connection = ActiveRecord::Base.connection
      return unless connection.data_source_exists?(OTP_CHALLENGES_TABLE)

      validate_schema!
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
      nil
    end
  end
end
