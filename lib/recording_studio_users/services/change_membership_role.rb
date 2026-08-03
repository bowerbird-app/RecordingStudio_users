# frozen_string_literal: true

require "recording_studio_users/services/membership_guard"

module RecordingStudioUsers
  module Services
    class ChangeMembershipRole < BaseService
      include MembershipGuard

      def initialize(recording:, access_recording:, role:, manager_actor:, controller: nil)
        @recording = recording
        @access_recording = access_recording
        @role = role.to_s
        @manager_actor = manager_actor
        @controller = controller
      end

      private

      def perform
        return failure("Access recording is required") unless @access_recording
        return update_access if @role == "admin"

        with_final_admin_guard { update_access }
      end

      def update_access
        RecordingStudioAccessible::Services::UpdateRecordingAccess.call(
          recording: @recording,
          access_recording: @access_recording,
          role: @role,
          manager_actor: @manager_actor,
          controller: @controller
        )
      end
    end
  end
end
