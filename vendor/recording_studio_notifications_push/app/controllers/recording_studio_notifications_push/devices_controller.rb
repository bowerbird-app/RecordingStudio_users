# frozen_string_literal: true

module RecordingStudioNotificationsPush
  class DevicesController < ApplicationController
    layout "recording_studio_notifications_push/blank"

    def show
      @installations = Installation.active.for_recipient(current_push_actor).order(last_seen_at: :desc)
      @firebase_web_config = RecordingStudioNotificationsPush.configuration.firebase_web_config
      @vapid_public_key = RecordingStudioNotificationsPush.configuration.vapid_public_key
      @firebase_ready = RecordingStudioNotificationsPush.configuration.web_push_client_ready?
      @service_worker_path = service_worker_path
      @notifications_settings_path = notifications_settings_path
    end

    def destroy
      installation = Installation.active.for_recipient(current_push_actor).find(params[:id])
      installation.disable!(reason: "removed")
      redirect_to devices_path, notice: "That device will stay quiet now."
    rescue ActiveRecord::RecordNotFound
      redirect_to devices_path, alert: "We could not find that device."
    end

    private

    def service_worker_path
      return unless respond_to?(:main_app, true)
      return unless main_app.respond_to?(:pwa_service_worker_path)

      main_app.pwa_service_worker_path(format: :js)
    rescue ArgumentError, NoMethodError
      nil
    end

    def notifications_settings_path
      return unless respond_to?(:recording_studio_notifications, true)

      recording_studio_notifications.settings_path
    rescue NoMethodError, ArgumentError
      nil
    end
  end
end
