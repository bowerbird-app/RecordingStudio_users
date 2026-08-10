# frozen_string_literal: true

module RecordingStudioUsers
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout -> { RecordingStudioUsers.configuration.layout }
    before_action :require_recording_studio_user!

    private

    def current_recording_studio_user
      @current_recording_studio_user ||= RecordingStudioUsers.current_actor(self)
    end
    helper_method :current_recording_studio_user

    def current_recording_studio_impersonator
      @current_recording_studio_impersonator ||= RecordingStudioUsers.current_impersonator(self)
    end

    def require_recording_studio_user!
      return if current_recording_studio_user&.persisted?
      return authenticate_user! if respond_to?(:authenticate_user!, true)

      head :unauthorized
    end
  end
end
