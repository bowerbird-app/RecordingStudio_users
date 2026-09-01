# frozen_string_literal: true

module RecordingStudioUser
  module OtpSetup
    module_function

    def validate_schema!
      user_class = RecordingStudioUser.config.user_class
      table = user_class.table_name
      columns = user_class.connection.columns(table).map(&:name)

      missing = []
      missing << "authentication_method on #{table}" unless columns.include?("authentication_method")
      %w[confirmation_token confirmed_at confirmation_sent_at unconfirmed_email].each do |column|
        missing << "#{column} on #{table}" unless columns.include?(column)
      end
      missing << "recording_studio_user_otp_challenges table" unless OtpChallenge.table_exists?

      return if missing.empty?

      raise(
        ArgumentError,
        "OTP is enabled but required schema is missing: #{missing.join(', ')}. " \
        "Run `rails generate recording_studio_user:migrations` and migrate."
      )
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
      return unless connection.data_source_exists?(OtpChallenge.table_name)

      validate_schema!
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
      nil
    end
  end
end
