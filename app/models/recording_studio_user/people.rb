# frozen_string_literal: true

module RecordingStudioUser
  class People < ApplicationRecord
    self.table_name = "recording_studio_user_people"

    recording_studio_recordable label: "People", root: true, shared: true

    before_create { self.created_at ||= Time.current }
  end
end
