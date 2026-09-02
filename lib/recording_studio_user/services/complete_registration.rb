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
        raise ArgumentError, "registration completion requires an OTP user" unless @user.registered_with_otp?
        raise ArgumentError, "challenge purpose must be registration" unless @challenge.registration?
      end

      def completed?
        @user.reload
        @user.confirmed? && RecordingStudioUser.profile_for(@user).present?
      end

      def confirm_and_provision!
        ActiveRecord::Base.transaction do
          persist_confirmation!
          RecordingStudioUser.record_profile!(@user, actor: @user, **Profile.default_attributes_for(@user))
        end

        @user.reload
      end

      def persist_confirmation!
        return if @user.reload.confirmed?

        raise ArgumentError, "OTP registration requires Devise confirmable" unless @user.respond_to?(:confirm)

        @user.confirm
        @user.reload
        return if @user.confirmed?

        raise ActiveRecord::RecordNotSaved, "OTP registration could not confirm user"
      end

      def instrument_completion!
        ActiveSupport::Notifications.instrument(
          "otp.registration_completed.recording_studio_user",
          user_id: @user.id,
          challenge_id: @challenge.id
        )
      end

      def roll_back_confirmation!
        @user.reload
        return unless @user.confirmed? && RecordingStudioUser.profile_for(@user).nil?

        @user.update_column(:confirmed_at, nil)
      end
    end
  end
end
