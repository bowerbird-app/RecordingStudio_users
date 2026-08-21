# frozen_string_literal: true

require "digest"
require "securerandom"

module RecordingStudioUsers
  class Invitation < ApplicationRecord
    self.table_name = "recording_studio_users_invitations"

    belongs_to :root_recording,
               class_name: "RecordingStudio::Recording",
               inverse_of: false
    belongs_to :inviter, polymorphic: true

    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :role, inclusion: { in: Authorization::ROLES }
    validates :status, inclusion: { in: %w[pending accepted revoked expired] }
    validates :token_digest, presence: true, uniqueness: true
    validate :root_recording_must_be_owned_root

    scope :pending, -> { where(status: "pending").where("expires_at > ?", Time.current) }

    def self.issue!(email:, root_recording:, role:, inviter:, expires_at: 7.days.from_now)
      token = SecureRandom.urlsafe_base64(32)
      invitation = create!(
        email: email,
        root_recording: root_recording,
        role: role,
        inviter: inviter,
        status: "pending",
        expires_at: expires_at,
        token_digest: digest(token)
      )
      [invitation, token]
    end

    def self.pending_for_token(token)
      return if token.blank?

      pending.find_by(token_digest: digest(token))
    end

    def self.digest(token)
      Digest::SHA256.hexdigest(token)
    end

    def accept!
      update!(status: "accepted", accepted_at: Time.current)
    end

    private

    def root_recording_must_be_owned_root
      return if root_recording && RecordingStudio.root_recording?(root_recording) &&
                !RecordingStudio.shared_root?(root_recording)

      errors.add(:root_recording, "must be an owned root")
    rescue StandardError
      errors.add(:root_recording, "must be an owned root")
    end
  end
end
