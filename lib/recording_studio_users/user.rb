# frozen_string_literal: true

module RecordingStudioUsers
  module User
    extend ActiveSupport::Concern

    included do
      has_one :recording_studio_users_user_root,
              as: :user,
              class_name: "RecordingStudioUsers::UserRoot",
              inverse_of: :user

      after_create :provision_recording_studio_user_profile, if: lambda {
        RecordingStudioUsers.configuration.auto_provision
      }
    end

    def recording_studio_users_profile
      RecordingStudioUsers.profile_for(self)
    end

    private

    def provision_recording_studio_user_profile
      result = RecordingStudioUsers.provision(self)
      raise RecordingStudioUsers::Error, result.error if result.failure?
    end
  end
end
