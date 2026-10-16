# frozen_string_literal: true

module RecordingStudioUser
  # Inserts an unconfirmed OTP user.
  #
  # Hosts need a case-insensitive unique index on users.email (a unique index
  # on LOWER(email) is the usual shape). Two requests can pass the application
  # check together. The database then raises RecordNotUnique and this returns
  # the row that won.
  module UnconfirmedUser
    def create_unconfirmed_user!(email:)
      raise ArgumentError, "OTP is not enabled" unless RecordingStudioUser.config.otp_enabled?

      normalized_email = email.to_s.strip.downcase
      save_unconfirmed_user!(normalized_email)
    rescue ActiveRecord::RecordNotUnique
      find_user_by_email!(normalized_email)
    end

    private

    def save_unconfirmed_user!(email)
      user = RecordingStudioUser.config.user_class.new(email: email, registered_with: "otp")
      user.skip_confirmation_notification! if user.respond_to?(:skip_confirmation_notification!)
      user.save!
      user
    end

    def find_user_by_email!(email)
      scope = RecordingStudioUser.config.user_class
      scope.find_by(email: email) || scope.where("LOWER(email) = ?", email).first!
    end
  end
end
