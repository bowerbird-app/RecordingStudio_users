# frozen_string_literal: true

module RecordingStudioUser
  class IdentitiesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_profile
    before_action :authorize_profile_edit!

    def destroy
      RecordingStudioUser::Omniauth.disconnect!(current_user, params[:provider])
      redirect_to sign_in_methods_profile_path, notice: "Sign-in method disconnected."
    rescue Omniauth::LastSignInMethodError => e
      redirect_to sign_in_methods_profile_path, alert: e.message
    rescue ActiveRecord::RecordNotFound
      redirect_to sign_in_methods_profile_path, alert: "That sign-in method is not connected."
    end

    private

    def set_profile
      @profile_recording = RecordingStudioUser.profile_recording_for(current_user)
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
