# frozen_string_literal: true

module RecordingStudioUsers
  class InvitationMailer < ActionMailer::Base
    def invite
      @invitation = params.fetch(:invitation)
      @accept_url = RecordingStudioUsers.configuration.invitation_url_for(
        invitation: @invitation,
        token: params.fetch(:token)
      )

      mail(
        from: RecordingStudioUsers.configuration.mailer_sender,
        to: @invitation.email,
        subject: "You’re invited to a workspace"
      )
    end
  end
end
