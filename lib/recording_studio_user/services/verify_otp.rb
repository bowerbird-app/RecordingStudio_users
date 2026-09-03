# frozen_string_literal: true

module RecordingStudioUser
  module Services
    class VerifyOtp
      Result = Struct.new(:success, :reason, :challenge, :user, keyword_init: true) do
        def success?
          success
        end
      end

      def self.call(...)
        new(...).call
      end

      def initialize(challenge_id:, code:, purpose:, session:)
        @challenge_id = challenge_id
        @code = code.to_s.strip
        @purpose = purpose.to_s
        @session = session
      end

      def call
        return failure(:session_mismatch) unless session_challenge_matches?

        result = consume_challenge
        instrument!(:verified, result.challenge) if result.success?
        result
      rescue ActiveRecord::RecordNotFound
        failure(:not_found)
      end

      private

      def consume_challenge
        OtpChallenge.transaction do
          challenge = OtpChallenge.lock.find_by(id: @challenge_id)
          return failure(:not_found) unless challenge

          rejection = rejection_reason(challenge)
          return failure(rejection, challenge: challenge) if rejection
          return record_failed_attempt(challenge) unless challenge.verify_code!(@code)

          challenge.consume!
          Result.new(success: true, reason: :verified, challenge: challenge, user: challenge.user)
        end
      end

      def record_failed_attempt(challenge)
        challenge.increment_attempts!
        failure(:invalid_code, challenge: challenge)
      end

      def rejection_reason(challenge)
        return :wrong_purpose unless challenge.purpose == @purpose
        return :expired if challenge.expired?
        return :consumed if challenge.consumed?
        return :revoked if challenge.revoked?
        return :too_many_attempts if challenge.attempts_count >= RecordingStudioUser.config.otp_max_attempts

        nil
      end

      def session_challenge_matches?
        @session[:otp_challenge_id].to_s == @challenge_id.to_s &&
          @session[:otp_purpose].to_s == @purpose
      end

      def failure(reason, challenge: nil)
        instrument!(:failed, challenge, reason: reason) if challenge
        Result.new(success: false, reason: reason, challenge: challenge, user: challenge&.user)
      end

      def instrument!(event, challenge, reason: nil)
        ActiveSupport::Notifications.instrument(
          "otp.#{event}.recording_studio_user",
          challenge_id: challenge&.id,
          user_id: challenge&.user_id,
          purpose: @purpose,
          reason: reason
        )
      end
    end
  end
end
