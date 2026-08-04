# frozen_string_literal: true

module RecordingStudioUsers
  class UserRoot < ApplicationRecord
    belongs_to :user, polymorphic: true

    recording_studio_recordable(
      label: "User profile root",
      plural_label: "User profile roots",
      root: true
    )
    RecordingStudio.enable_capability(:accessible, on: self)

    validates :user_type, :user_id, presence: true
    validates :user_id, uniqueness: {scope: :user_type}
    validate :user_must_be_persisted

    def recordable_name = "User profile root"

    private

    def user_must_be_persisted
      errors.add(:user, "must be persisted") unless user&.persisted?
    end
  end
end
