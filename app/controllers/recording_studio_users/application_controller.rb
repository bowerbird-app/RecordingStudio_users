# frozen_string_literal: true

module RecordingStudioUsers
  class ApplicationController < ActionController::Base
    include RecordingStudio::RootSwitchable::ControllerSupport if
      defined?(RecordingStudio::RootSwitchable::ControllerSupport)

    protect_from_forgery with: :exception
    layout -> { RecordingStudioUsers.configuration.layout_for(controller: self) }

    before_action :set_membership_context
    before_action :authorize_membership_management!

    private

    attr_reader :current_actor, :current_root_recording
    helper_method :current_actor, :current_root_recording

    def set_membership_context
      @current_actor = RecordingStudioUsers.configuration.current_actor_for(controller: self)
      @current_root_recording = RecordingStudioUsers.configuration.current_root_for(controller: self)
      head :not_found unless current_root_recording
    end

    def authorize_membership_management!
      return if performed?
      return if RecordingStudioUsers.configuration.authorized?(
        controller: self,
        actor: current_actor,
        root_recording: current_root_recording
      )

      head :forbidden
    end
  end
end
