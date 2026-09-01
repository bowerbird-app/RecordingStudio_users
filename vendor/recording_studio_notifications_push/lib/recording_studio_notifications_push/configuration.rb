# frozen_string_literal: true

module RecordingStudioNotificationsPush
  class Configuration
    WEB_CLIENT_REQUIRED_KEYS = %i[apiKey appId projectId messagingSenderId].freeze

    WEB_CONFIG_ENV_KEYS = {
      apiKey: "FIREBASE_API_KEY",
      appId: "FIREBASE_APP_ID",
      authDomain: "FIREBASE_AUTH_DOMAIN",
      messagingSenderId: "FIREBASE_MESSAGING_SENDER_ID",
      projectId: "FIREBASE_PROJECT_ID",
      storageBucket: "FIREBASE_STORAGE_BUCKET"
    }.freeze

    attr_accessor :channel, :firebase_project_id, :firebase_web_config, :vapid_public_key,
                  :firebase_service_account_json, :open_timeout, :read_timeout, :write_timeout

    def initialize
      @channel = :push
      @firebase_project_id = ENV.fetch("FIREBASE_PROJECT_ID", nil)
      @firebase_web_config = default_firebase_web_config
      @vapid_public_key = ENV.fetch("FIREBASE_VAPID_PUBLIC_KEY", nil)
      @firebase_service_account_json = ENV.fetch("FIREBASE_SERVICE_ACCOUNT_JSON", nil)
      @open_timeout = 5
      @read_timeout = 15
      @write_timeout = 15
    end

    def merge!(attributes)
      return self unless attributes.respond_to?(:each)

      attributes.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
      self
    end

    def to_h
      {
        channel: channel.to_sym,
        firebase_project_id: firebase_project_id,
        firebase_web_config: firebase_web_config.to_h,
        vapid_public_key: vapid_public_key,
        firebase_service_account_configured: firebase_service_account_json.to_s.strip.present?,
        open_timeout: open_timeout,
        read_timeout: read_timeout,
        write_timeout: write_timeout
      }
    end

    def service_account_configured?
      firebase_service_account_json.to_s.strip.present?
    end

    def web_push_client_ready?
      config = firebase_web_config || {}
      WEB_CLIENT_REQUIRED_KEYS.all? { |key| web_config_value_present?(config, key) } &&
        vapid_public_key.present?
    end

    private

    def web_config_value_present?(config, key)
      config[key].present? || config[key.to_s].present?
    end

    def default_firebase_web_config
      WEB_CONFIG_ENV_KEYS.each_with_object({}) do |(key, env_name), config|
        value = ENV.fetch(env_name, nil)
        config[key] = value if value.present?
      end
    end
  end
end
