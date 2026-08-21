# frozen_string_literal: true

module RecordingStudioUsers
  class MembershipsController < ApplicationController
    before_action :require_explicit_root!
    before_action :require_root!
    before_action :authorize_admin!
    before_action :set_access_recording

    def update
      result = RecordingStudioAccessible::Services::UpdateRecordingAccess.call(
        recording: current_root_recording,
        access_recording: @access_recording,
        role: membership_params[:role],
        manager_actor: current_actor,
        controller: self
      )
      redirect_with_result(result, success: "Role updated.")
    end

    def destroy
      result = RecordingStudioAccessible::Services::RevokeRecordingAccess.call(
        recording: current_root_recording,
        access_recording: @access_recording,
        manager_actor: current_actor,
        controller: self
      )
      redirect_with_result(result, success: "Access removed.")
    end

    private

    def membership_params
      params.require(:membership).permit(:role)
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

    def set_access_recording
      @access_recording = RecordingStudioAccessible
                          .access_recordings_for(current_root_recording)
                          .find { |recording| recording.id.to_s == params[:id].to_s }
      head :not_found unless @access_recording
    end

    def redirect_with_result(result, success:)
      destination = invitations_path(root_recording_id: current_root_recording.id)
      if result.success?
        redirect_to destination, notice: success
      else
        redirect_to destination, alert: result.error
      end
    end
  end
end
