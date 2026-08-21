# frozen_string_literal: true

module RecordingStudioUsers
  class ApplicationController < ActionController::Base
    include RecordingStudio::RootSwitchable::ControllerSupport

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

      store_authentication_location
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
        selected = RecordingStudio::RootSwitchable.current_root_recording
        roots.find { |root| root.id.to_s == requested_id.to_s } ||
          roots.find { |root| root.id == selected&.id } ||
          roots.first
      end
    end

    def require_root!
      return if current_root_recording

      redirect_to onboarding_path
    end

    def store_authentication_location
      return unless respond_to?(:store_location_for, true)

      send(
        :store_location_for,
        RecordingStudioUsers.configuration.authentication_scope,
        request.fullpath
      )
    end
  end
end
