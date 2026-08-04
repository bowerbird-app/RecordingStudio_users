# frozen_string_literal: true

module RecordingStudioUsers
  class Profile < ApplicationRecord
    recording_studio_recordable(
      label: "User profile",
      plural_label: "User profiles",
      root: false,
      allowed_parent_types: ["RecordingStudioUsers::UserRoot"]
    )

    include RecordingStudio::Capabilities::Attachable.to(
      allowed_content_types: RecordingStudioUsers.configuration.avatar_content_types,
      max_file_size: RecordingStudioUsers.configuration.avatar_max_byte_size,
      max_file_count: 1,
      enabled_attachment_kinds: %i[image],
      authorize_with: RecordingStudioUsers::AvatarAuthorization
    )

    validates :locale, length: {maximum: 64}, allow_blank: true
    validates :time_zone, length: {maximum: 128}, allow_blank: true
    validates :display_name, length: {maximum: 160}, allow_blank: true
    validates :biography, length: {maximum: 5000}, allow_blank: true

    def recordable_name
      display_name.to_s.squish.presence || "User profile"
    end
  end
end
