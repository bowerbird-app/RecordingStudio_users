# frozen_string_literal: true

module RecordingStudioUser
  module Services
    # Asks for a one-time code without revealing whether the address exists.
    #
    # Order is fixed: normalize the email, reserve the rate limit, find or
    # create the unconfirmed user, then issue. A throttled request returns
    # before any insert. Login never creates a user.
    class RequestOtp
      def self.call(...)
        new(...).call
      end

      def initialize(email:, purpose:, request:, session:)
        @email = email
        @purpose = purpose.to_s
        @request = request
        @session = session
      end

      def call
        prepare!
        keys = rate_limit_keys
        return finish(IssueOtp::Result.throttled) unless reserve_rate_limit!(keys)

        deliverable? ? issue(keys) : finish(IssueOtp::Result.suppressed)
      end

      private

      def issue(keys)
        IssueOtp.call(
          user: @user, purpose: @purpose, request: @request, session: @session, checked_keys: keys
        )
      end

      def prepare!
        OtpSetup.validate_schema!
        raise ArgumentError, "unknown purpose" unless OtpChallenge::PURPOSES.include?(@purpose)

        @normalized_email = OtpRateLimiter.normalize_email(@email)
      end

      def deliverable?
        return false if @normalized_email.blank?

        @user = find_or_create_user
        issuable?(@user)
      end

      def finish(result)
        clear_otp_session!
        result
      end

      def clear_otp_session!
        return unless @session

        @session.delete(:otp_challenge_id)
        @session.delete(:otp_purpose)
        @session.delete(:otp_user_id)
      end

      def reserve_rate_limit!(keys)
        OtpRateLimiter.allow_requests!(scope: :issue, keys: keys)
        true
      rescue OtpRateLimiter::RateLimited
        false
      end

      def rate_limit_keys
        [
          OtpRateLimiter.limit_key(:email, OtpRateLimiter.email_key(@normalized_email)),
          OtpRateLimiter.limit_key(:ip, @request&.remote_ip),
          OtpRateLimiter.limit_key(:session, session_id)
        ].compact
      end

      def session_id
        return if @session.blank? || @session.is_a?(Hash)
        return unless @session.respond_to?(:id)

        @session.id
      end

      def find_or_create_user
        existing = find_user
        return existing if existing
        return unless @purpose == "registration"

        Directory.create_unconfirmed_user!(email: @normalized_email)
      end

      def find_user
        user_class = RecordingStudioUser.config.user_class
        user_class.find_by(email: @normalized_email) ||
          user_class.where("LOWER(email) = ?", @normalized_email).first
      end

      def issuable?(user)
        return false if user.blank? || disabled?(user)

        case @purpose
        when "registration" then registration_pending?(user)
        when "confirmation" then PasswordConfirmation.pending?(user)
        else user.confirmed? && user.active_for_authentication?
        end
      end

      def disabled?(user)
        return false unless user.respond_to?(:active_for_authentication?)
        return true if user.respond_to?(:access_locked?) && user.access_locked?
        return false if waiting_for_email_code?(user)

        !user.active_for_authentication?
      end

      def waiting_for_email_code?(user)
        registration_pending?(user) || PasswordConfirmation.pending?(user)
      end

      def registration_pending?(user)
        user.respond_to?(:registered_with_otp?) && user.registered_with_otp? && !user.confirmed?
      end
    end
  end
end
