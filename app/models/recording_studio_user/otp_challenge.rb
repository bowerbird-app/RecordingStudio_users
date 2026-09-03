# frozen_string_literal: true

module RecordingStudioUser
  class OtpChallenge < ApplicationRecord
    self.table_name = "recording_studio_user_otp_challenges"

    PURPOSES = %w[registration login].freeze

    belongs_to :user, class_name: RecordingStudioUser.config.user_class_name

    validates :purpose, inclusion: { in: PURPOSES }
    validates :code_digest, presence: true
    validates :expires_at, presence: true

    scope :active, lambda {
      where(consumed_at: nil, revoked_at: nil).where("expires_at > ?", Time.current)
    }

    def registration?
      purpose == "registration"
    end

    def login?
      purpose == "login"
    end

    def active?
      !expired? && !consumed? && !revoked? && attempts_count < RecordingStudioUser.config.otp_max_attempts
    end

    def expired?
      expires_at <= Time.current
    end

    def consumed?
      consumed_at.present?
    end

    def revoked?
      revoked_at.present?
    end

    def deliverable?
      active?
    end

    def verify_code!(submitted)
      secure_compare(submitted)
    end

    def consume!
      update!(consumed_at: Time.current, delivery_code_ciphertext: nil)
    end

    def revoke!
      update!(revoked_at: Time.current, delivery_code_ciphertext: nil)
    end

    def increment_attempts!
      increment!(:attempts_count)
      revoke! if attempts_count >= RecordingStudioUser.config.otp_max_attempts
    end

    def decrypt_delivery_code!
      return if delivery_code_ciphertext.blank?

      self.class.decrypt_code(delivery_code_ciphertext)
    end

    def clear_delivery_ciphertext!
      update_column(:delivery_code_ciphertext, nil) if delivery_code_ciphertext.present?
    end

    class << self
      def generate_code
        format("%06d", SecureRandom.random_number(1_000_000))
      end

      def digest_code(code)
        OpenSSL::HMAC.hexdigest("SHA256", hmac_key, code.to_s)
      end

      def encrypt_code(code)
        encryptor.encrypt_and_sign(code.to_s)
      end

      def decrypt_code(ciphertext)
        encryptor.decrypt_and_verify(ciphertext)
      end

      def issue_for!(user:, purpose:, code: generate_code)
        create!(
          user: user,
          purpose: purpose,
          code_digest: digest_code(code),
          delivery_code_ciphertext: encrypt_code(code),
          expires_at: RecordingStudioUser.config.otp_expires_in.from_now,
          delivery_requested_at: Time.current
        )
      end

      private

      def encryptor
        @encryptor ||= ActiveSupport::MessageEncryptor.new(encryption_key)
      end

      def encryption_key
        ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
          "recording studio otp delivery", 32
        )
      end

      def hmac_key
        ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
          "recording studio otp verify", 32
        )
      end
    end

    private

    def secure_compare(submitted)
      ActiveSupport::SecurityUtils.secure_compare(
        self.class.digest_code(submitted.to_s),
        code_digest.to_s
      )
    end
  end
end
