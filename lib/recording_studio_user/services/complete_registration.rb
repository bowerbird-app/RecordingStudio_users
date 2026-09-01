# frozen_string_literal: true

module RecordingStudioUser
  module Services
    class CompleteRegistration
      def self.call(...)
        new(...).call
      end

      def initialize(user:, challenge:)
        @user = user
        @challenge = challenge
      end

      def call
        raise ArgumentError, "registration completion requires an OTP user" unless @user.otp_authentication_method?
        raise ArgumentError, "challenge purpose must be registration" unless @challenge.registration?

        return @user if @user.confirmed? && RecordingStudioUser.profile_for(@user)

        ActiveRecord::Base.transaction do
          @user.confirm unless @user.confirmed?
          RecordingStudioUser.record_profile!(@user, actor: @user, **default_profile_attributes)
        end

        ActiveSupport::Notifications.instrument(
          "otp.registration_completed.recording_studio_user",
          user_id: @user.id,
          challenge_id: @challenge.id
        )

        @user
      rescue StandardError
        @user.update_column(:confirmed_at, nil) if @user.confirmed? && RecordingStudioUser.profile_for(@user).nil?
        raise
      end

      def default_profile_attributes
        local = @user.email.to_s.split("@").first.to_s
        {
          first_name: local.presence || "Account",
          last_name: "Member",
          time_zone: "UTC"
        }
      end
    end
  end
end
