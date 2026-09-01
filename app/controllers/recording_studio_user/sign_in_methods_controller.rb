# frozen_string_literal: true

module RecordingStudioUser
  class SignInMethodsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_profile
    before_action :authorize_profile_edit!

    def show
      @identities = current_user.usable_identities.order(:provider)
    end

    private

    def set_profile
      @user = current_user
      @profile_recording = RecordingStudioUser.profile_recording_for(current_user)
      @profile = @profile_recording&.recordable
    end

    def authorize_profile_edit!
      return if @profile_recording.present? && RecordingStudioAccessible.authorized?(
        actor: current_user,
        recording: @profile_recording,
        role: :edit
      )

      head :forbidden
    end
  end
end
