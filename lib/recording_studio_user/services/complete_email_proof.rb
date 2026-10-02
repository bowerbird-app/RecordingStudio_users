# frozen_string_literal: true

module RecordingStudioUser
  module Services
    class CompleteEmailProof
      def self.call(...)
        new(...).call
      end

      def initialize(user:, challenge_id:, profile_attributes: {})
        @user = user
        @challenge_id = challenge_id
        @profile_attributes = (profile_attributes || {}).to_h.symbolize_keys
        @started_confirmed = false
      end

      def call
        validate!
        @started_confirmed = @user.reload.confirmed?
        persist_confirmation! unless @started_confirmed
        write_profile_if_missing!
        instrument!
        @user.reload
      rescue StandardError
        roll_back_confirmation! unless @started_confirmed
        raise
      end

      private

      def validate!
        raise ArgumentError, "challenge is not eligible" unless eligible_challenge?
      end

      def eligible_challenge?
        challenge.present? &&
          challenge.user_id.to_s == @user.id.to_s &&
          challenge.consumed? &&
          OtpChallenge::PURPOSES.include?(challenge.purpose)
      end

      def challenge
        @challenge ||= OtpChallenge.find_by(id: @challenge_id)
      end

      def persist_confirmation!
        raise ArgumentError, "email proof requires Devise confirmable" unless @user.respond_to?(:confirm)

        @user.confirm
        @user.reload
        return if @user.confirmed?

        raise ActiveRecord::RecordNotSaved, "email proof could not confirm user"
      end

      def write_profile_if_missing!
        return if RecordingStudioUser.profile_for(@user).present?

        first_name = @profile_attributes[:first_name].to_s.strip.presence
        return if first_name.blank?

        RecordingStudioUser.record_profile!(
          @user,
          actor: @user,
          first_name: first_name,
          last_name: @profile_attributes[:last_name].to_s.strip.presence,
          time_zone: nil
        )
      end

      def instrument!
        ActiveSupport::Notifications.instrument(
          "otp.email_proof_completed.recording_studio_user",
          user_id: @user.id,
          challenge_id: challenge.id
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
