# frozen_string_literal: true

module RecordingStudioSiteSettings
  class SiteSetting < ApplicationRecord
    self.table_name = "recording_studio_site_settings"

    RECORDABLE_LABEL = "Site settings"

    def self.declare_hierarchy!
      recording_studio_recordable label: RECORDABLE_LABEL,
                                  root: false,
                                  allowed_parent_types: RecordingStudioSiteSettings.configuration.site_root_types
    end

    declare_hierarchy!

    include RecordingStudio::Capabilities::Attachable.to(
      allowed_content_types: ["image/*"],
      enabled_attachment_kinds: %i[image],
      max_file_count: 3
    )

    self.record_timestamps = false

    validates :name, presence: true

    before_create { self.created_at ||= Time.current }
  end
end
