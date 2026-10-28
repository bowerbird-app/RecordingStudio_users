# frozen_string_literal: true

module RecordingStudioUser
  class ProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_profile
    before_action :authorize_profile_access!

    def show; end

    def edit; end

    def update
      save_profile!
      apply_profile_image!
      redirect_to profile_path, notice: updated_notice
    rescue ActiveRecord::RecordInvalid => e
      render_invalid_profile(e.record)
    rescue RecordingStudioAttachable::Authorization::NotAuthorizedError
      head :forbidden
    rescue ArgumentError, RecordingStudioAttachable::Error => e
      render_attachable_error(e)
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

    def render_invalid_profile(profile)
      @profile = profile
      render :edit, status: :unprocessable_entity
    end

    def render_attachable_error(error)
      flash.now[:alert] = error.message
      render :edit, status: :unprocessable_entity
    end

    def save_profile!
      RecordingStudioUser.record_profile!(current_user, actor: current_user, **profile_write_attributes)
    end

    def apply_profile_image!
      blob_id = profile_image_param(:signed_blob_id)
      if blob_id.present?
        authorize_provider_upload!
        RecordingStudioUser.assign_profile_image!(current_user, signed_blob_id: blob_id, actor: current_user)
      elsif profile_image_param(:remove) == "1"
        RecordingStudioUser.remove_profile_image!(current_user, actor: current_user)
      end
    end

    # Attachable's supported upload authorization helper. Finds the Profile
    # recording (already loaded for this screen) and authorizes :upload.
    def authorize_provider_upload!
      RecordingStudioAttachable::Authorization.authorize!(
        action: :upload,
        actor: current_user,
        recording: @profile_recording
      )
    end

    def profile_image_param(key)
      image = params[:profile_image]
      return if image.blank?

      image[key].to_s.strip.presence
    end

    def profile_write_attributes
      attrs = profile_params.to_h.symbolize_keys
      extras = attrs.extract!(*RecordingStudioUser.config.additional_profile_attributes)
      attrs.merge(additional_profile_attributes: extras)
    end

    def updated_notice
      I18n.with_locale(locale_for_notice) { I18n.t("recording_studio_user.profile.updated") }
    end

    def locale_for_notice
      return I18n.locale unless params[:user]&.key?(:locale)

      code = params[:user][:locale].to_s.strip
      return I18n.default_locale if code.blank?

      available = Array(I18n.available_locales).map(&:to_s)
      available.include?(code) ? code : I18n.locale
    end
  end
end
