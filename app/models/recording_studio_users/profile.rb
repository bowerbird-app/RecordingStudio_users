# frozen_string_literal: true

module RecordingStudioUsers
  class Profile < ::ApplicationRecord
    self.table_name = "recording_studio_users_profiles"

    validates :display_name, length: { maximum: 120 }, allow_blank: true
    validates :biography, length: { maximum: 5000 }, allow_blank: true
    validates :locale, length: { maximum: 20 }, allow_blank: true
    validates :time_zone, length: { maximum: 120 }, allow_blank: true

    recording_studio_recordable(
      label: "User profile",
      plural_label: "User profiles",
      root: false,
      allowed_parent_types: ["RecordingStudioUsers::UserRoot"]
    )

    if defined?(RecordingStudioAttachable) && defined?(RecordingStudio)
      RecordingStudio.enable_capability(:attachable, on: self)
    end

    def recordable_name
      value = display_name.to_s.strip
      value.present? ? value : "User profile"
    end
  end
end
