# frozen_string_literal: true

module RecordingStudioUser
  # Grants and checks Accessible roles on Profile recordings.
  module ProfileAccess
    OWNER_ROLE = :admin
    UNAUTHORIZED_MANAGEMENT_MESSAGE = "Not authorized to manage access"

    AUTHORIZER_MUTEX = Mutex.new
    private_constant :AUTHORIZER_MUTEX

    module_function

    def ensure_owner_access!(user, recording, manager_actor: nil)
      return recording if recording.blank? || user.blank?
      return recording if authorized?(user, recording, role: OWNER_ROLE)

      grant_owner_access!(user, recording, manager_actor: manager_actor)
      recording
    end

    def grant_owner_access!(user, recording, manager_actor: nil)
      manager = manager_actor.presence || user
      result = attempt_grant(recording, user, manager)
      result = grant_first_owner(recording, user, manager) if first_owner_retry?(result, recording, user)
      raise result.error if result.failure?

      result.value
    end

    def authorized?(user, recording, role:)
      return false if user.blank? || recording.blank?

      RecordingStudioAccessible.authorized?(actor: user, recording: recording, role: role)
    end

    def role_for(user, recording)
      return if user.blank? || recording.blank?

      RecordingStudioAccessible.role_for(actor: user, recording: recording)
    end

    def attempt_grant(recording, user, manager)
      RecordingStudioAccessible.grant_access(
        recording: recording,
        actor: user,
        role: OWNER_ROLE,
        manager_actor: manager
      )
    end

    def first_owner_retry?(result, recording, user)
      result.failure? &&
        result.error.to_s.include?(UNAUTHORIZED_MANAGEMENT_MESSAGE) &&
        profile_owned_by?(recording, user) &&
        no_direct_grants?(recording)
    end

    def grant_first_owner(recording, user, manager)
      AUTHORIZER_MUTEX.synchronize do
        config = RecordingStudioAccessible.configuration
        original = config.access_management_authorizer
        begin
          config.access_management_authorizer = ->(**) { true }
          attempt_grant(recording, user, manager)
        ensure
          config.access_management_authorizer = original
        end
      end
    end

    def profile_owned_by?(recording, user)
      recordable = recording.recordable
      recordable.is_a?(Profile) && recordable.user_id == user.id
    end

    def no_direct_grants?(recording)
      RecordingStudioAccessible.access_recordings_for(recording).none?
    end
  end
end
