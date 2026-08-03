# frozen_string_literal: true

module RecordingStudioUsers
  class UserRoot < ::ApplicationRecord
    self.table_name = "recording_studio_users_user_roots"

    belongs_to :user, polymorphic: true, inverse_of: :recording_studio_users_user_root

    validates :user_id, uniqueness: { scope: :user_type }

    recording_studio_recordable(
      label: "User profile root",
      plural_label: "User profile roots",
      root: true
    )

    if defined?(RecordingStudio)
      RecordingStudio.enable_capability(:accessible, on: self)
    end

    def recordable_name
      return user.name if user.respond_to?(:name) && user.name.present?
      return user.email if user.respond_to?(:email) && user.email.present?

      "User profile root"
    end
  end
end
