# frozen_string_literal: true

require "monitor"
require "openssl"
require "uri"
require "rails"
require "recording_studio_notifications"
require "recording_studio_notifications_push/version"

module RecordingStudioNotificationsPush
  class ConfigurationError < StandardError; end
  class DeliveryError < StandardError; end
end

require "recording_studio_notifications_push/configuration"
require "recording_studio_notifications_push/event"
require "recording_studio_notifications_push/google_access_token"
require "recording_studio_notifications_push/fcm_client"
require "recording_studio_notifications_push/fcm_adapter"
require "recording_studio_notifications_push/test_push"
require "recording_studio_notifications_push/engine"

module RecordingStudioNotificationsPush
  class << self
    def configuration
      configuration_mutex.synchronize { @configuration ||= Configuration.new }
    end
    alias config configuration

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def adapter
      configuration_mutex.synchronize do
        @adapter ||= FcmAdapter.new(configuration: configuration)
      end
    end

    def register!
      unless defined?(RecordingStudioNotifications) &&
             RecordingStudioNotifications.respond_to?(:register_channel)
        raise ConfigurationError, "recording_studio_notifications must expose register_channel"
      end

      RecordingStudioNotifications.register_channel(configuration.channel, adapter)
      adapter
    end

    def reset_configuration!
      configuration_mutex.synchronize do
        @configuration = Configuration.new
        @adapter = nil
      end
    end

    private

    def configuration_mutex
      @configuration_mutex ||= Monitor.new
    end
  end
end
