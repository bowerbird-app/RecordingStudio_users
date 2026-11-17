# frozen_string_literal: true

module RecordingStudioUser
  # One-time sign-in link issued while codes are paused. Only the digest is
  # stored. The raw token exists in the email that is sent in this request,
  # then the saved notice is rewritten without it.
  class SignInLink < ApplicationRecord
    self.table_name = "recording_studio_user_sign_in_links"

    HMAC_SALT = "recording studio sign in link"
    IDEMPOTENCY_PREFIX = "sign-in-link"

    belongs_to :user, class_name: RecordingStudioUser.config.user_class_name

    validates :token_digest, :expires_at, presence: true

    def self.deliver!(user)
      return false if user.blank? || !defined?(RecordingStudioNotifications)

      raw, link = issue!(user)
      SignInLinkMail.deliver!(user, raw, link)
      true
    rescue StandardError => e
      Rails.logger.error("RecordingStudioUser sign-in link email failed: #{e.class}")
      false
    end

    def self.authenticate!(token)
      return if token.blank?

      link = find_by(token_digest: digest(token))
      return if link.nil?

      link.with_lock { consume!(link) }
    end

    def self.issue!(user)
      raw = SecureRandom.urlsafe_base64(32)
      link = transaction do
        retire_unused!(user)
        create!(user: user, token_digest: digest(raw), expires_at: link_expires_at)
      end
      [raw, link]
    end

    def self.digest(token)
      OpenSSL::HMAC.hexdigest("SHA256", hmac_key, token.to_s)
    end

    def self.consume!(link)
      return if spent?(link)

      user = link.user
      link.update!(consumed_at: Time.current)
      user if user&.confirmed? && user.active_for_authentication?
    end
    private_class_method :consume!

    def self.spent?(link)
      link.consumed_at.present? || link.expires_at <= Time.current
    end
    private_class_method :spent?

    def self.retire_unused!(user)
      where(user_id: user.id, consumed_at: nil).update_all(consumed_at: Time.current, updated_at: Time.current)
    end
    private_class_method :retire_unused!

    def self.link_expires_at
      RecordingStudioUser.config.otp_expires_in.from_now
    end
    private_class_method :link_expires_at

    def self.hmac_key
      ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(HMAC_SALT, 32)
    end
    private_class_method :hmac_key
  end

  # Sends the link, then drops the raw token from the stored notice.
  module SignInLinkMail
    module_function

    def deliver!(user, raw, link)
      RecordingStudioNotifications.notify(**notice(user, url_for(raw), link))
    ensure
      scrub!(link)
    end

    def notice(user, url, link)
      {
        notification_type: :sign_in_link,
        recipient: user,
        title: I18n.t("recording_studio_user.auth.sign_in_link.title"),
        body: I18n.t("recording_studio_user.auth.sign_in_link.body", minutes: expiry_minutes, url: url),
        channels: [:email],
        metadata: { "sign_in_link_id" => link.id },
        idempotency_key: "#{SignInLink::IDEMPOTENCY_PREFIX}/#{link.id}",
        deliver_later: false
      }
    end

    def scrub!(link)
      notification = RecordingStudioNotifications::Notification.find_by(
        idempotency_key: "#{SignInLink::IDEMPOTENCY_PREFIX}/#{link.id}"
      )
      return if notification.blank?

      notification.update_columns(
        body: I18n.t("recording_studio_user.auth.sign_in_link.stored_body", minutes: expiry_minutes),
        url: nil,
        updated_at: Time.current
      )
    end

    def url_for(token)
      RecordingStudioUser::Engine.routes.url_helpers.sign_in_link_url(
        **url_options, script_name: RecordingStudioUser.config.mount_path, sign_in_token: token
      )
    end

    def url_options
      routes = Rails.application.routes.default_url_options || {}
      mailer = Rails.application.config.action_mailer.default_url_options || {}
      routes.merge(mailer).symbolize_keys
    end

    def expiry_minutes
      (RecordingStudioUser.config.otp_expires_in / 60).to_i
    end
  end
end
