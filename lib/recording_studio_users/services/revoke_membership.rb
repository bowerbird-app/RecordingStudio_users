# frozen_string_literal: true

require "recording_studio_users/services/membership_guard"

module RecordingStudioUsers
  module Services
    class RevokeMembership < BaseService
      include MembershipGuard

      def initialize(recording:, access_recording:, manager_actor:, controller: nil)
        @recording = recording
        @access_recording = access_recording
        @manager_actor = manager_actor
        @controller = controller
      end

      private

      def perform
        return failure("Access recording is required") unless @access_recording

        with_final_admin_guard do
          RecordingStudioAccessible::Services::RevokeRecordingAccess.call(
            recording: @recording,
            access_recording: @access_recording,
            manager_actor: @manager_actor,
            controller: @controller
          )
        end
      end
    end
  end
end
