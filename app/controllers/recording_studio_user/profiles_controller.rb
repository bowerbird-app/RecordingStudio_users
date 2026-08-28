# frozen_string_literal: true

module RecordingStudioUser
  class ProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_profile
    before_action :authorize_profile_access!

    def show; end

    def edit; end

    def update
      RecordingStudioUser.record_profile!(
        current_user,
        actor: current_user,
        **profile_write_attributes
      )
      redirect_to profile_path, notice: "Profile updated."
    rescue ActiveRecord::RecordInvalid => e
      @profile = e.record
      render :edit, status: :unprocessable_entity
    end

    private

    def set_profile
      @user = current_user
      @profile_recording = RecordingStudioUser.profile_recording_for(current_user)
      @profile = @profile_recording&.recordable
    end

    def authorize_profile_access!
      return if @profile_recording.present? && RecordingStudioAccessible.authorized?(
        actor: current_user,
        recording: @profile_recording,
        role: required_profile_role
      )

      head :forbidden
    end

    def required_profile_role
      action_name == "show" ? :view : :edit
    end

    def profile_params
      params.require(:user).permit(*permitted_profile_attributes)
    end

    def permitted_profile_attributes
      %i[first_name last_name time_zone] + RecordingStudioUser.config.additional_profile_attributes
    end

    def profile_write_attributes
      attrs = profile_params.to_h.symbolize_keys
      extras = attrs.extract!(*RecordingStudioUser.config.additional_profile_attributes)
      attrs.merge(additional_profile_attributes: extras)
    end
  end
end
