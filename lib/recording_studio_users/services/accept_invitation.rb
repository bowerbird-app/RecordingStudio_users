# frozen_string_literal: true

module RecordingStudioUsers
  module Services
    class AcceptInvitation
      def self.call(...)
        new(...).call
      end

      def initialize(token:, actor:, controller: nil, device_key: nil)
        @token = token.to_s
        @actor = actor
        @controller = controller
        @device_key = device_key
      end

      def call
        invitation = Invitation.pending_for_token(@token)
        return Result.failure("That invitation is invalid or has expired") unless invitation
        return Result.failure("Sign in with #{invitation.email} to accept this invitation") unless matching_email?(invitation)

        grant_result = RecordingStudioAccessible.grant_access(
          recording: invitation.root_recording,
          actor: @actor,
          role: invitation.role,
          manager_actor: invitation.inviter
        )
        return Result.failure(grant_result.error) if grant_result.failure?

        invitation.accept!
        switch_result = switch_root(invitation.root_recording)
        return Result.failure(Array(switch_result.errors).to_sentence) unless switch_result.success?

        Result.success(invitation.root_recording)
      rescue ActiveRecord::RecordInvalid => e
        Result.failure(e.record.errors.full_messages.to_sentence)
      end

      private

      def matching_email?(invitation)
        RecordingStudioUsers.configuration.email_for(actor: @actor) == invitation.email
      end

      def switch_root(root_recording)
        RecordingStudio::RootSwitchable.switch_root(
          root_recording_id: root_recording.id,
          scope_key: RecordingStudioUsers.configuration.root_scope_key,
          controller: @controller,
          actor: @actor,
          device_key: @device_key
        )
      end
    end
  end
end
