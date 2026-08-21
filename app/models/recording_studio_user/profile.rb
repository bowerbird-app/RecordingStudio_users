# frozen_string_literal: true

module RecordingStudioUser
  class Profile < ApplicationRecord
    self.table_name = "recording_studio_user_profiles"

    ALLOWED_PARENT_TYPES = ["RecordingStudioUser::People"].freeze

    recording_studio_recordable label: "Profile",
                                root: false,
                                allowed_parent_types: ALLOWED_PARENT_TYPES
    RecordingStudio.enable_capability(:accessible, on: self)

    belongs_to :user, class_name: "User", inverse_of: false

    validates :first_name, :last_name, :time_zone, presence: true
    validates :time_zone, inclusion: { in: ->(_record) { ActiveSupport::TimeZone.all.map(&:name) } }

    before_create { self.created_at ||= Time.current }

    def additional_profile_attributes
      super || {}
    end
  end
end
