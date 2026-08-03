# frozen_string_literal: true

module RecordingStudioUsers
  module Services
    class GrantMembership < BaseService
      def initialize(recording:, user:, role:, manager_actor:, controller: nil)
        @recording = recording
        @user = user
        @role = role
        @manager_actor = manager_actor
        @controller = controller
      end

      private

      def perform
        return failure("User is required") unless @user

        RecordingStudioAccessible::Services::GrantRecordingAccess.call(
          recording: @recording,
          actor: @user,
          role: @role,
          manager_actor: @manager_actor,
          controller: @controller
        )
      end
    end
  end
end
