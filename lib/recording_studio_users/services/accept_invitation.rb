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
        unless matching_email?(invitation)
          return Result.failure("Sign in with #{invitation.email} to accept this invitation")
        end

        grant_result = grant_and_accept(invitation)
        return grant_result if grant_result.failure?

        select_root(invitation.root_recording)
        Result.success(invitation.root_recording)
      rescue ActiveRecord::RecordInvalid => e
        Result.failure(e.record.errors.full_messages.to_sentence)
      end

      private

      def matching_email?(invitation)
        RecordingStudioUsers.configuration.email_for(actor: @actor) == invitation.email
      end

      def grant_and_accept(invitation)
        result = nil
        ActiveRecord::Base.transaction do
          result = RecordingStudioAccessible.grant_access(
            recording: invitation.root_recording,
            actor: @actor,
            role: invitation.role,
            manager_actor: invitation.inviter
          )
          raise ActiveRecord::Rollback if result.failure?

          invitation.accept!
        end
        result.success? ? Result.success(invitation) : Result.failure(result.error)
      end

      def switch_root(root_recording)
        ActiveRecord::Base.uncached do
          RecordingStudio::RootSwitchable.switch_root(
            root_recording_id: root_recording.id,
            scope_key: RecordingStudioUsers.configuration.root_scope_key,
            controller: @controller,
            actor: @actor,
            device_key: @device_key
          )
        end
      end

      def select_root(root_recording)
        result = switch_root(root_recording)
        return if result.success?

        Rails.logger.warn("RecordingStudioUsers could not select accepted root: #{result.errors.to_sentence}")
      rescue StandardError => e
        Rails.logger.warn("RecordingStudioUsers could not select accepted root: #{e.class}")
      end
    end
  end
end
