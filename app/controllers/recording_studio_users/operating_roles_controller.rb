# frozen_string_literal: true

module RecordingStudioUsers
  class OperatingRolesController < ApplicationController
    before_action :require_explicit_root!
    before_action :require_root!

    def update
      role = RecordingStudioUsers.set_operating_role!(
        actor: current_actor,
        recording: current_root_recording,
        role: params[:role],
        session: session
      )

      redirect_to RecordingStudioUsers.configuration.after_role_switch_path_for(controller: self),
                  notice: "Now working as #{role}."
    rescue RecordingStudioUsers::Authorization::NotAuthorized => e
      redirect_to RecordingStudioUsers.configuration.after_role_switch_path_for(controller: self),
                  alert: e.message
    end
  end
end
