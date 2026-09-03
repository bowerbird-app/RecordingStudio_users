# frozen_string_literal: true

module RecordingStudioUser
  class Profile < ApplicationRecord
    self.table_name = "recording_studio_user_profiles"

    ALLOWED_PARENT_TYPES = ["RecordingStudioUser::People"].freeze
    ATTACHABLE_OPTIONS = {
      allowed_content_types: ["image/*"],
      enabled_attachment_kinds: %i[image],
      max_file_count: 1
    }.freeze

    recording_studio_recordable label: "Profile",
                                root: false,
                                allowed_parent_types: ALLOWED_PARENT_TYPES
    RecordingStudio.enable_capability(:accessible, on: self)
    include RecordingStudio::Capabilities::Attachable.to(**ATTACHABLE_OPTIONS)

    belongs_to :user, class_name: "User", inverse_of: false

    validates :first_name, :last_name, :time_zone, presence: true
    validates :time_zone, inclusion: { in: ->(_record) { ActiveSupport::TimeZone.all.map(&:name) } }

    before_create { self.created_at ||= Time.current }

    # Registration asks for an email before any name, so a new profile starts
    # from the email local part until the person edits it.
    def self.default_attributes_for(user)
      local = user.email.to_s.split("@").first.to_s
      { first_name: local.presence || "Account", last_name: "Member", time_zone: "UTC" }
    end

    def additional_profile_attributes
      super || {}
    end
  end
end
