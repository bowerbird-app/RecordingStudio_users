# frozen_string_literal: true

module RecordingStudioUser
  # Checks Accessible roles on Profile recordings. First-owner grants use
  # RecordingStudioAccessible.bootstrap_owner_access!; later membership uses grant_access.
  module ProfileAccess
    OWNER_ROLE = :admin

    module_function

    def authorized?(user, recording, role:)
      return false if user.blank? || recording.blank?

      RecordingStudioAccessible.authorized?(actor: user, recording: recording, role: role)
    end

    def role_for(user, recording)
      return if user.blank? || recording.blank?

      RecordingStudioAccessible.role_for(actor: user, recording: recording)
    end

    def grant_membership!(recording:, actor:, role:, manager_actor:)
      result = RecordingStudioAccessible.grant_access(
        recording: recording,
        actor: actor,
        role: role,
        manager_actor: manager_actor
      )
      raise result.error if result.failure?

      result.value
    end
  end
end
