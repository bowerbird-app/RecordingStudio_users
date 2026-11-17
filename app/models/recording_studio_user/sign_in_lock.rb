# frozen_string_literal: true

module RecordingStudioUser
  # One row per lock event. +notified_at+ is set after the single email for
  # that row, so a later failure cannot send another.
  class SignInLock < ApplicationRecord
    self.table_name = "recording_studio_user_sign_in_locks"

    KINDS = %w[otp password].freeze

    belongs_to :user, class_name: RecordingStudioUser.config.user_class_name

    validates :kind, inclusion: { in: KINDS }
    validates :locked_at, presence: true

    def self.latest_for(user, kind)
      where(user_id: user.id, kind: kind.to_s).order(locked_at: :desc).first
    end
  end
end
