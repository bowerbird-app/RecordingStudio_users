# frozen_string_literal: true

module RecordingStudioUsers
  class InvitationsController < ApplicationController
    before_action :require_root!, except: %i[accept redeem]

    def index
      authorize_admin!
      @memberships = RecordingStudioAccessible.access_recordings_for(current_root_recording)
      @invitations = Invitation.where(root_recording: current_root_recording).order(created_at: :desc)
      @selected_email = params[:email].to_s
      @selected_role = params[:role].presence || "view"
    end

    def create
      result = Services::CreateInvitation.call(
        email: invitation_params[:email],
        recording: current_root_recording,
        role: invitation_params[:role],
        inviter: current_actor,
        operating_role: current_operating_role
      )

      if result.success?
        redirect_to invitations_path(root_recording_id: current_root_recording.id),
                    notice: "Invitation sent."
      else
        redirect_to invitations_path(root_recording_id: current_root_recording.id),
                    alert: result.error
      end
    end

    def accept
      @invitation = Invitation.pending_for_token(params[:token])
      render :invalid, status: :not_found unless @invitation
    end

    def redeem
      result = Services::AcceptInvitation.call(
        token: params[:token],
        actor: current_actor,
        controller: self,
        device_key: device_key
      )

      if result.success?
        redirect_to invitations_path(root_recording_id: result.value.id),
                    notice: "You’re in. Welcome aboard."
      else
        redirect_to onboarding_path, alert: result.error
      end
    end

    private

    def invitation_params
      params.require(:invitation).permit(:email, :role)
    end

    def authorize_admin!
      RecordingStudioUsers.authorize!(
        actor: current_actor,
        recording: current_root_recording,
        role: :admin,
        mode: :both,
        session: session
      )
    end

    def device_key
      RecordingStudio::RootSwitchable::DeviceKey.fetch(controller: self)
    rescue RecordingStudio::RootSwitchable::DeviceKey::Unavailable
      nil
    end
  end
end
