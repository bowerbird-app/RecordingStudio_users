# frozen_string_literal: true

module RecordingStudioUser
  module Services
    # Asks for a code when a sibling gem already has the email.
    #
    # Login and registration stay behind their own flags. A flag that is off
    # does not create a user or send a code, and the result looks the same as
    # an address that cannot receive one.
    class StartOtpChallenge
      # Same key as Auth::PendingEmail::AUTH_EMAIL_KEY.
      EMAIL_KEY = :auth_email

      def self.call(...)
        new(...).call
      end

      def initialize(request:, email:, return_to: nil, popup: nil)
        @request = request
        @email = email
        @return_to = return_to
        @popup = popup
      end

      def call
        raise ArgumentError, "request is required" if @request.nil?

        remember_navigation!
        return IssueOtp::Result.suppressed if normalized_email.blank?

        session[EMAIL_KEY] = normalized_email
        purpose = purpose_for(existing_user)
        return request_code(purpose) if purpose

        suppress!
      end

      private

      def session
        @request.session
      end

      def remember_navigation!
        ReturnTo.remember(session, @return_to, popup: popup_flag)
      end

      def popup_flag
        return "1" if @popup == true || @popup.to_s == "1"

        nil
      end

      def normalized_email
        @normalized_email ||= OtpRateLimiter.normalize_email(@email)
      end

      def existing_user
        user_class = RecordingStudioUser.config.user_class
        user_class.find_by(email: normalized_email) ||
          user_class.where("LOWER(email) = ?", normalized_email).first
      end

      def purpose_for(user)
        return unless RecordingStudioUser.config.otp_enabled?

        user ? purpose_for_existing(user) : registration_purpose
      end

      def purpose_for_existing(user)
        if registration_pending?(user)
          registration_purpose
        elsif RecordingStudioUser.config.otp_login_enabled?
          :login
        end
      end

      def registration_purpose
        :registration if RecordingStudioUser.config.otp_registration_enabled?
      end

      def registration_pending?(user)
        user.respond_to?(:registered_with_otp?) && user.registered_with_otp? && !user.confirmed?
      end

      def request_code(purpose)
        RecordingStudioUser.request_otp!(
          email: normalized_email,
          purpose: purpose,
          request: @request,
          session: session
        )
      end

      def suppress!
        return IssueOtp::Result.throttled unless reserve_issue_limit!

        clear_otp_session!
        IssueOtp::Result.suppressed
      end

      def reserve_issue_limit!
        OtpRateLimiter.allow_requests!(scope: :issue, keys: limit_keys)
        true
      rescue OtpRateLimiter::RateLimited
        false
      end

      def limit_keys
        [OtpRateLimiter.email_key(normalized_email), @request.remote_ip, session_id].compact_blank
      end

      def session_id
        return unless session.respond_to?(:id)

        session.id
      end

      def clear_otp_session!
        session.delete(:otp_challenge_id)
        session.delete(:otp_purpose)
        session.delete(:otp_user_id)
      end
    end
  end
end
