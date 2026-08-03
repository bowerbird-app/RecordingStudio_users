# frozen_string_literal: true

module RecordingStudioUsers
  module Services
    module MembershipGuard
      FINAL_ADMIN_ERROR = "The final admin cannot be removed or demoted"

      private

      def with_final_admin_guard
        RecordingStudio::Recording.transaction do
          @recording.lock!
          return failure(FINAL_ADMIN_ERROR) if final_admin_target?

          yield
        end
      end

      def final_admin_target?
        return false unless @access_recording.recordable.admin?

        direct_access_recordings.count { |recording| recording.recordable.admin? } <= 1
      end

      def direct_access_recordings
        RecordingStudioAccessible::DirectAccessQuery.access_recordings_for(@recording).preload(:recordable)
      end
    end
  end
end
