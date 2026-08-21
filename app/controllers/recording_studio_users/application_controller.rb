# frozen_string_literal: true

module RecordingStudioUsers
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout -> { RecordingStudioUsers.configuration.layout }

    before_action :require_actor!

    helper_method :current_actor, :current_operating_role, :current_root_recording

    rescue_from RecordingStudioUsers::Authorization::NotAuthorized do
      render plain: "Forbidden", status: :forbidden
    end

    private

    def current_actor
      @current_actor ||= RecordingStudioUsers.configuration.current_actor_for(controller: self)
    end

    def require_actor!
      return if current_actor

      redirect_to RecordingStudioUsers.configuration.authentication_path_for(controller: self)
    end

    def current_operating_role
      return unless current_root_recording

      RecordingStudioUsers.current_operating_role(
        actor: current_actor,
        recording: current_root_recording,
        session: session
      )
    end

    def current_root_recording
      @current_root_recording ||= begin
        requested_id = params[:root_recording_id].presence
        roots = RecordingStudioAccessible.root_recordings_for(actor: current_actor)
        requested_id ? roots.find { |root| root.id.to_s == requested_id.to_s } : roots.first
      end
    end

    def require_root!
      return if current_root_recording

      redirect_to onboarding_path
    end
  end
end
