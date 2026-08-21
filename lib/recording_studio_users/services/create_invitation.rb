# frozen_string_literal: true

module RecordingStudioUsers
  module Services
    class CreateInvitation
      def self.call(...)
        new(...).call
      end

      def initialize(email:, recording:, role:, inviter:, operating_role: nil)
        @email = email.to_s.strip.downcase
        @recording = recording
        @role = role.to_s
        @inviter = inviter
        @operating_role = operating_role
      end

      def call
        return Result.failure("Enter an email address") if @email.blank?
        return Result.failure("Choose a valid role") unless Authorization::ROLES.include?(@role)

        RecordingStudioUsers.authorize!(
          actor: @inviter,
          recording: @recording,
          role: :admin,
          mode: :both,
          operating_role: @operating_role
        )

        invitation, token = Invitation.issue!(
          email: @email,
          root_recording: @recording,
          role: @role,
          inviter: @inviter
        )
        InvitationMailer.with(invitation: invitation, token: token).invite.deliver_later
        Result.success(invitation)
      rescue Authorization::NotAuthorized => e
        Result.failure(e.message)
      rescue ActiveRecord::RecordInvalid => e
        Result.failure(e.record.errors.full_messages.to_sentence)
      end
    end
  end
end
