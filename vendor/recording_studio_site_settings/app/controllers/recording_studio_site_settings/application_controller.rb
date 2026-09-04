# frozen_string_literal: true

module RecordingStudioSiteSettings
  class ApplicationController < ActionController::Base
    include Devise::Controllers::Helpers if defined?(Devise::Controllers::Helpers)
    include RecordingStudio::UsesDefaultLayout

    if defined?(RecordingStudio::RootSwitchable::ControllerSupport)
      include RecordingStudio::RootSwitchable::ControllerSupport
    end

    protect_from_forgery with: :exception
    layout "recording_studio/default_layout"

    helper RecordingStudio::LayoutHelper if defined?(RecordingStudio::LayoutHelper)
    helper RecordingStudioAttachable::ApplicationHelper if defined?(RecordingStudioAttachable::ApplicationHelper)
    include Rails.application.routes.mounted_helpers

    helper Rails.application.routes.mounted_helpers

    helper_method :recording_studio_admin_context

    rescue_from RecordingStudioAdmin::AuthorizationFailed, with: :render_forbidden
    rescue_from RecordingStudioAdmin::DefinitionNotFound, with: :render_forbidden
    rescue_from RecordingStudioSiteSettings::Unauthorized, with: :render_forbidden

    before_action :authenticate_recording_studio_site_settings!
    before_action :set_current_actor

    private

    def authenticate_recording_studio_site_settings!
      method_name = RecordingStudioAdmin.configuration.authentication_method
      return send(method_name) if method_name && respond_to?(method_name, true)

      head :unauthorized
    end

    def set_current_actor
      return unless defined?(Current) && Current.respond_to?(:actor=)

      Current.actor = current_actor
    end

    def current_actor
      method_name = RecordingStudioAdmin.configuration.current_actor_method
      return send(method_name) if method_name && respond_to?(method_name, true)

      Current.actor if defined?(Current)
    end

    def recording_studio_admin_context
      @recording_studio_admin_context ||= RecordingStudioAdmin::Context.new(
        params: params.to_unsafe_h,
        current_actor: current_actor,
        controller: self,
        routes: main_app,
        view_context: view_context
      )
    end

    def render_forbidden
      head :forbidden
    end
  end
end
