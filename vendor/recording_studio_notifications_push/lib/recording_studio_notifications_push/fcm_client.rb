# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module RecordingStudioNotificationsPush
  class FcmClient
    FCM_SCOPE_HOST = "https://fcm.googleapis.com"

    def initialize(configuration: RecordingStudioNotificationsPush.configuration,
                   access_token_provider: nil)
      @configuration = configuration
      @access_token_provider = access_token_provider
    end

    # Sends one FCM HTTP v1 message. Returns a result hash:
    #   { ok: true/false, status: Integer, body: Hash, disable: Boolean }
    def send_message(token:, title:, body: nil, url: nil, data: {})
      raise DeliveryError, "FCM token is required" if token.to_s.strip.blank?
      raise DeliveryError, "FIREBASE_PROJECT_ID is required to send push notifications" if project_id.blank?

      response = post_json(messages_uri, build_payload(token:, title:, body:, url:, data:))
      parse_response(response)
    end

    private

    # Data-only web payloads. When a service worker handles `push`, Chrome does
    # not auto-display an FCM `notification` block — the worker must call
    # showNotification. Including both blocks duplicated banners before dedupe.
    def build_payload(token:, title:, body:, url:, data:)
      {
        message: {
          token: token.to_s,
          data: stringify_data(data.merge("title" => title, "body" => body, "url" => url).compact),
          webpush: webpush_options(url)
        }.compact
      }
    end

    def project_id
      @configuration.firebase_project_id.to_s.strip.presence ||
        @configuration.firebase_web_config[:projectId].to_s.strip.presence ||
        @configuration.firebase_web_config["projectId"].to_s.strip.presence
    end

    def messages_uri
      URI.parse("#{FCM_SCOPE_HOST}/v1/projects/#{project_id}/messages:send")
    end

    def access_token
      (@access_token_provider || default_access_token_provider).fetch
    end

    def default_access_token_provider
      json = @configuration.firebase_service_account_json
      if json.to_s.strip.blank?
        raise DeliveryError, "FIREBASE_SERVICE_ACCOUNT_JSON is required to send push notifications"
      end

      @default_access_token_provider ||= GoogleAccessToken.new(
        service_account_json: json,
        open_timeout: @configuration.open_timeout,
        read_timeout: @configuration.read_timeout,
        write_timeout: @configuration.write_timeout
      )
    end

    def post_json(uri, payload)
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json; charset=utf-8"
      request.body = JSON.generate(payload)
      build_http(uri).request(request)
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
      raise DeliveryError, "FCM network error: #{e.message}"
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = @configuration.open_timeout
      http.read_timeout = @configuration.read_timeout
      http.write_timeout = @configuration.write_timeout if http.respond_to?(:write_timeout=)
      http
    end

    def parse_response(response)
      body = parse_json_body(response.body)
      {
        ok: response.is_a?(Net::HTTPSuccess),
        status: response.code.to_i,
        body: body,
        disable: disable_token?(body),
        error_message: body.dig("error", "message")
      }
    end

    def disable_token?(body)
      error_status = body.dig("error", "status").to_s
      error_code = Array(body.dig("error", "details")).filter_map { |detail| detail["errorCode"] }.first
      error_message = body.dig("error", "message").to_s

      return true if %w[UNREGISTERED NOT_FOUND].include?(error_status)
      return true if %w[UNREGISTERED NOT_FOUND].include?(error_code.to_s)
      return true if error_status == "INVALID_ARGUMENT" && /not a valid fcm registration token/i.match?(error_message)

      false
    end

    def parse_json_body(raw)
      JSON.parse(raw.to_s.presence || "{}")
    rescue JSON::ParserError
      { "raw" => raw.to_s }
    end

    def stringify_data(hash)
      hash.each_with_object({}) do |(key, value), result|
        next if value.nil?

        result[key.to_s] = value.is_a?(String) ? value : value.to_s
      end
    end

    def webpush_options(url)
      options = {
        # Urgency helps some browsers deliver while a tab is focused.
        headers: { Urgency: "high" }
      }
      options[:fcm_options] = { link: url.to_s } if url.present?
      options
    end
  end
end
