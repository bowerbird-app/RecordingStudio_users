# frozen_string_literal: true

module RecordingStudioNotificationsPush
  # Sends one diagnostic FCM message to a single installation and reports what
  # FCM answered. This exists so "FCM refused the token" can be told apart from
  # "FCM accepted it and the browser never displayed it".
  class TestPush
    Result = Struct.new(:accepted, :status, :error, keyword_init: true) do
      def accepted?
        accepted
      end

      def to_h
        { accepted: accepted, status: status, error: error }.compact
      end
    end

    TITLE = "Push test"
    BODY = "If you can read this, this browser can show push."

    def initialize(client: nil, configuration: RecordingStudioNotificationsPush.configuration)
      @client = client
      @configuration = configuration
    end

    def call(installation:)
      token = installation.delivery_token
      return Result.new(accepted: false, error: "this device has no push token") if token.to_s.strip.empty?

      result = send_probe(token)
      installation.touch_seen! if result[:ok] && installation.respond_to?(:touch_seen!)
      build_result(result)
    rescue DeliveryError => e
      Result.new(accepted: false, error: e.message)
    end

    private

    def send_probe(token)
      client.send_message(
        token: token,
        title: TITLE,
        body: BODY,
        url: "/",
        data: { "test_push" => "1" }
      )
    end

    def build_result(result)
      Result.new(
        accepted: result[:ok],
        status: result[:status],
        error: result[:ok] ? nil : (result[:error_message].presence || "FCM send failed (HTTP #{result[:status]})")
      )
    end

    def client
      @client ||= FcmClient.new(configuration: @configuration)
    end
  end
end
