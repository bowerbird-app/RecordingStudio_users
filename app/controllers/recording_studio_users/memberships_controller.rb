# frozen_string_literal: true

module RecordingStudioUsers
  class MembershipsController < ApplicationController
    before_action :set_access_recording, only: %i[update destroy]

    def index
      @memberships = direct_access_recordings.map do |access_recording|
        {
          access_recording: access_recording,
          user: access_recording.recordable.actor,
          role: access_recording.recordable.role
        }
      end
    end

    def create
      user = RecordingStudioUsers.configuration.user_for(controller: self, email: membership_params[:email])
      result = Services::GrantMembership.call(
        recording: current_root_recording,
        user: user,
        role: membership_params[:role],
        manager_actor: current_actor,
        controller: self
      )
      respond_with_result(result, success_notice: "Workspace member added.")
    end

    def update
      result = Services::ChangeMembershipRole.call(
        recording: current_root_recording,
        access_recording: @access_recording,
        role: membership_params[:role],
        manager_actor: current_actor,
        controller: self
      )
      respond_with_result(result, success_notice: "Workspace role updated.")
    end

    def destroy
      result = Services::RevokeMembership.call(
        recording: current_root_recording,
        access_recording: @access_recording,
        manager_actor: current_actor,
        controller: self
      )
      respond_with_result(result, success_notice: "Workspace member removed.")
    end

    private

    def direct_access_recordings
      RecordingStudioAccessible::DirectAccessQuery
        .access_recordings_for(current_root_recording)
        .preload(recordable: :actor)
        .order(created_at: :asc, id: :asc)
    end

    def set_access_recording
      @access_recording = direct_access_recordings.find(params[:id])
    end

    def membership_params
      params.require(:membership).permit(:email, :role)
    end

    def respond_with_result(result, success_notice:)
      if result.success?
        redirect_to root_path, notice: success_notice, status: :see_other
      else
        redirect_to root_path, alert: Array(result.errors).presence&.to_sentence || result.error,
                               status: :see_other
      end
    end
  end
end
