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
        validate!
        return @user if completed?

        confirm_and_provision!
        instrument_completion!
        @user
      rescue StandardError
        roll_back_confirmation!
        raise
      end

      private

      def validate!
        raise ArgumentError, "registration completion requires an OTP user" unless @user.otp_authentication_method?
        raise ArgumentError, "challenge purpose must be registration" unless @challenge.registration?
      end

      def completed?
        @user.confirmed? && RecordingStudioUser.profile_for(@user).present?
      end

      def confirm_and_provision!
        ActiveRecord::Base.transaction do
          @user.confirm unless @user.confirmed?
          RecordingStudioUser.record_profile!(@user, actor: @user, **Profile.default_attributes_for(@user))
        end
      end

      def instrument_completion!
        ActiveSupport::Notifications.instrument(
          "otp.registration_completed.recording_studio_user",
          user_id: @user.id,
          challenge_id: @challenge.id
        )
      end

      def roll_back_confirmation!
        return unless @user.confirmed? && RecordingStudioUser.profile_for(@user).nil?

        @user.update_column(:confirmed_at, nil)
      end
    end
  end
end
