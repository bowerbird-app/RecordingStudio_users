# frozen_string_literal: true

require "active_support/core_ext/numeric/time"
require "recording_studio_user/code_sign_in_copy"

module RecordingStudioUser
  class CodeSignInToken
    PURPOSE = "recording_studio_user/code_sign_in"
    DEFAULT_EXPIRES_IN = 30.days

    Claim = Data.define(:user_id, :email, :return_to, :salt, :title, :reason) do
      def matches?(user)
        return false if user.blank? || user.id.blank?
        return false unless user.id.to_s == user_id.to_s

        current_email = Services::OtpRateLimiter.normalize_email(user.email)
        return false unless current_email == email

        salts_match?(user)
      end

      def salts_match?(user)
        current = user.respond_to?(:authenticatable_salt) ? user.authenticatable_salt.to_s : ""
        claimed = salt.to_s
        return false unless current.bytesize == claimed.bytesize

        ActiveSupport::SecurityUtils.secure_compare(current, claimed)
      end
    end

    class << self
      def issue(user:, return_to: nil, expires_in: DEFAULT_EXPIRES_IN, title: nil, reason: nil)
        raise ArgumentError, "user is required" if user.blank? || user.id.blank?

        email = Services::OtpRateLimiter.normalize_email(user.email)
        raise ArgumentError, "user email is required" if email.blank?

        verifier.generate(
          payload_for(user, email, return_to, title, reason),
          expires_in: expires_in,
          purpose: PURPOSE
        )
      end

      def read(token)
        return if token.blank?

        payload = verifier.verified(token.to_s, purpose: PURPOSE)
        return if payload.blank?

        claim_from(payload)
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        nil
      end

      def url(...)
        link(:user_code_sign_in_url, ...)
      end

      def path(...)
        link(:user_code_sign_in_path, ...)
      end

      def url_options
        routes = Rails.application.routes.default_url_options || {}
        mailer = Rails.application.config.action_mailer.default_url_options || {}
        routes.merge(mailer).symbolize_keys
      end

      private

      def link(helper, user:, return_to: nil, expires_in: DEFAULT_EXPIRES_IN, title: nil, reason: nil)
        token = issue(user:, return_to:, expires_in:, title:, reason:)
        options = helper.to_s.end_with?("_url") ? url_options : {}
        Rails.application.routes.url_helpers.public_send(helper, **options, code_sign_in_token: token)
      end

      def payload_for(user, email, return_to, title, reason)
        {
          "user_id" => user.id,
          "email" => email,
          "return_to" => ReturnTo.accept(return_to),
          "salt" => salt_for(user),
          "title" => CodeSignInCopy.pack(title),
          "reason" => CodeSignInCopy.pack(reason)
        }.compact
      end

      def claim_from(payload)
        data = string_hash(payload)
        return unless data && data["user_id"].present? && data["email"].present?

        copies = CodeSignInCopy.pair(data["title"], data["reason"])
        claim_for(data, copies) if copies
      end

      def string_hash(payload)
        data = payload.respond_to?(:stringify_keys) ? payload.stringify_keys : payload
        data if data.is_a?(Hash)
      end

      def claim_for(data, copies)
        Claim.new(
          user_id: data["user_id"],
          email: Services::OtpRateLimiter.normalize_email(data["email"]),
          return_to: ReturnTo.accept(data["return_to"]),
          salt: data["salt"].to_s,
          title: copies[0],
          reason: copies[1]
        )
      end

      def salt_for(user)
        return "" unless user.respond_to?(:authenticatable_salt)

        user.authenticatable_salt.to_s
      end

      def verifier
        Rails.application.message_verifier(PURPOSE)
      end
    end
  end

  class << self
    def code_sign_in_url(...) = CodeSignInToken.url(...)
    def code_sign_in_path(...) = CodeSignInToken.path(...)
  end
end
