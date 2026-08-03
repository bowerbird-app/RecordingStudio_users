# frozen_string_literal: true

module RecordingStudioUsers
  module User
    extend ActiveSupport::Concern

    included do
      has_one :recording_studio_users_user_root,
              class_name: "RecordingStudioUsers::UserRoot",
              as: :user,
              inverse_of: :user
    end

    def recording_studio_users_profile
      RecordingStudioUsers.profile_for(self)
    end

    def recording_studio_users_root
      RecordingStudioUsers.user_root_for(self)
    end
  end
end
