# frozen_string_literal: true

module RecordingStudioUser
  module OtpSetup
    module_function

    REQUIRED_USER_COLUMNS = %w[
      authentication_method confirmation_token confirmed_at confirmation_sent_at unconfirmed_email
    ].freeze
    OTP_CHALLENGES_TABLE = "recording_studio_user_otp_challenges"

    def validate_schema!
      missing = missing_schema
      return if missing.empty?

      raise(
        ArgumentError,
        "OTP is enabled but required schema is missing: #{missing.join(', ')}. " \
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
            "OTP is enabled but recording_studio_notifications is not installed. " \
            "Add the gem and run its install generator."
    end

    def validate_schema_when_ready!
      return unless RecordingStudioUser.config.otp_enabled?

      connection = ActiveRecord::Base.connection
      return unless connection.data_source_exists?(OTP_CHALLENGES_TABLE)

      validate_schema!
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
      nil
    end
  end
end
