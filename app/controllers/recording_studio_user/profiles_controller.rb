# frozen_string_literal: true

module RecordingStudioUser
  class ProfilesController < ApplicationController
    before_action :authenticate_user!

    def show
      @user = current_user
    end

    def edit
      @user = current_user
    end

    def update
      @user = current_user

      if @user.update(profile_params)
        redirect_to profile_path, notice: "Profile updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def profile_params
      params.require(:user).permit(*permitted_profile_attributes)
    end

    def permitted_profile_attributes
      %i[first_name last_name time_zone] + RecordingStudioUser.config.additional_profile_attributes
    end
  end
end
