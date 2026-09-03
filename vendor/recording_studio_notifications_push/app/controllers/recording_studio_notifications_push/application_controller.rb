# frozen_string_literal: true

module RecordingStudioNotificationsPush
  parent_controller = defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base

  class ApplicationController < parent_controller
    protect_from_forgery with: :exception

    before_action :require_push_actor!

    helper_method :current_push_actor

    # HTML screens (e.g. devices) may override with an engine blank layout.
    # Prefer the host app shell for everything else; fall back to Recording
    # Studio default layout when the host has not set one.
    layout :push_application_layout

    private

    def push_application_layout
      if respond_to?(:application_layout, true)
        application_layout
      elsif defined?(::RecordingStudio::UsesDefaultLayout)
        "recording_studio/default_layout"
      end
    end

    def current_push_actor
      @current_push_actor ||= begin
        actor = current_user if respond_to?(:current_user, true)
        actor ||= Current.actor if defined?(Current) && Current.respond_to?(:actor)
        actor
      end
    end

    def require_push_actor!
      return if current_push_actor

      if respond_to?(:authenticate_user!, true)
        authenticate_user!
      else
        head :unauthorized
      end
    end
  end
end
