# frozen_string_literal: true

module RecordingStudioUser
  # One row per wrong password on an account. The lockout count is the number
  # of rows inside the window. A successful password sign-in deletes them.
  class PasswordFailure < ApplicationRecord
    self.table_name = "recording_studio_user_password_failures"

    belongs_to :user, class_name: RecordingStudioUser.config.user_class_name

    def self.count_for(user, window_start:, after:)
      scope = where(user_id: user.id).where(created_at: window_start..)
      scope = scope.where("created_at > ?", after) if after
      scope.count
    end
  end
end
