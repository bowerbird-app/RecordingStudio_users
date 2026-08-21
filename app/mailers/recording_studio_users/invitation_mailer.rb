# frozen_string_literal: true

module RecordingStudioUsers
  class InvitationMailer < ActionMailer::Base
    default from: "no-reply@example.com"

    def invite
      @invitation = params.fetch(:invitation)
      @accept_url = RecordingStudioUsers.configuration.invitation_url_for(
        invitation: @invitation,
        token: params.fetch(:token)
      )

      mail(to: @invitation.email, subject: "You’re invited to a workspace")
    end
  end
end
