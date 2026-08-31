# frozen_string_literal: true

module RecordingStudioUser
  class Identity < ApplicationRecord
    self.table_name = "recording_studio_user_identities"

    belongs_to :user, class_name: RecordingStudioUser.config.user_class_name, inverse_of: :identities

    validates :provider, presence: true
    validates :uid, presence: true
    validates :uid, uniqueness: { scope: :provider }
    validates :provider, uniqueness: { scope: :user_id }
  end
end
