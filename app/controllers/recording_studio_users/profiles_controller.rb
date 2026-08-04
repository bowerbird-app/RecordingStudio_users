# frozen_string_literal: true

module RecordingStudioUsers
  class ProfilesController < ApplicationController
    before_action :load_profile, except: :security

    def show; end

    def edit; end

    def update
      result = RecordingStudioUsers.revise_profile(
        user: current_recording_studio_user,
        actor: current_recording_studio_user,
        impersonator: current_recording_studio_impersonator,
        attributes: profile_params
      )
      return redirect_to(profile_path, notice: "Profile updated.") if result.success?

      @profile = result.value || @profile
      flash.now[:alert] = result.error
      render :edit, status: :unprocessable_entity
    end

    def upload_avatar
      mutate_avatar(:upload_avatar, success_message: "Avatar uploaded.")
    end

    def replace_avatar
      mutate_avatar(:replace_avatar, success_message: "Avatar replaced.")
    end

    def remove_avatar
      mutate_avatar(:remove_avatar, success_message: "Avatar removed.", requires_blob: false)
    end

    def security; end

    private

    def load_profile
      @profile = RecordingStudioUsers.profile_for(current_recording_studio_user)
      @avatar = RecordingStudioUsers.avatar_for(
        current_recording_studio_user,
        context: {actor: current_recording_studio_user}
      )
      @avatar_recording = RecordingStudioUsers.avatar_recording_for(current_recording_studio_user)
    end

    def profile_params
      params.require(:profile).permit(*RecordingStudioUsers.configuration.profile_fields)
    end

    def mutate_avatar(method_name, success_message:, requires_blob: true)
      arguments = {
        user: current_recording_studio_user,
        actor: current_recording_studio_user,
        impersonator: current_recording_studio_impersonator
      }
      arguments[:signed_blob_id] = signed_blob_id if requires_blob
      result = RecordingStudioUsers.public_send(method_name, **arguments)
      return redirect_to(profile_path, notice: success_message) if result.success?

      redirect_to(profile_path, alert: result.error)
    end

    def signed_blob_id
      return params[:signed_blob_id] if params[:signed_blob_id].present?

      upload = params[:avatar]
      raise ActionController::BadRequest, "Avatar file is required" unless upload.respond_to?(:open)

      blob = ActiveStorage::Blob.create_and_upload!(
        io: upload.open,
        filename: upload.original_filename,
        content_type: upload.content_type,
        identify: true
      )
      blob.signed_id
    end
  end
end
