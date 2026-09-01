# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"

module RecordingStudioNotificationsPush
  # Exchanges a Firebase / Google service-account JSON key for an OAuth access
  # token using a hand-rolled RS256 JWT. No googleauth dependency.
  class GoogleAccessToken
    TOKEN_URI = "https://oauth2.googleapis.com/token"
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
    EXPIRY_SKEW = 60

    def initialize(service_account_json:, open_timeout: 5, read_timeout: 15, write_timeout: 15)
      @credentials = parse_credentials(service_account_json)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @write_timeout = write_timeout
      @mutex = Mutex.new
      @cached_token = nil
      @expires_at = Time.at(0)
    end

    def fetch
      @mutex.synchronize do
        return @cached_token if @cached_token.present? && Time.now < (@expires_at - EXPIRY_SKEW)

        response = exchange_jwt!(build_jwt)
        @cached_token = response.fetch("access_token")
        @expires_at = Time.now + Integer(response.fetch("expires_in", 3600))
        @cached_token
      end
    end

    def clear!
      @mutex.synchronize do
        @cached_token = nil
        @expires_at = Time.at(0)
      end
    end

    private

    def parse_credentials(raw)
      payload = raw.is_a?(Hash) ? raw : JSON.parse(raw.to_s)
      credentials_from_payload(payload)
    rescue JSON::ParserError => e
      raise ArgumentError, "service account JSON is invalid: #{e.message}"
    end

    def credentials_from_payload(payload)
      client_email = payload["client_email"].to_s.strip
      private_key = payload["private_key"].to_s
      raise ArgumentError, "service account JSON must include client_email" if client_email.blank?
      raise ArgumentError, "service account JSON must include private_key" if private_key.blank?

      {
        "client_email" => client_email,
        "private_key" => private_key,
        "token_uri" => payload["token_uri"].presence || TOKEN_URI
      }
    end

    def build_jwt
      now = Time.now.to_i
      encoded_header = urlsafe_encode64(JSON.generate({ alg: "RS256", typ: "JWT" }))
      encoded_claims = urlsafe_encode64(JSON.generate(jwt_claims(now)))
      signing_input = "#{encoded_header}.#{encoded_claims}"
      signature = urlsafe_encode64(rsa_key.sign(OpenSSL::Digest.new("SHA256"), signing_input))
      "#{signing_input}.#{signature}"
    end

    def jwt_claims(now)
      {
        iss: @credentials.fetch("client_email"),
        scope: SCOPE,
        aud: @credentials.fetch("token_uri"),
        iat: now,
        exp: now + 3600
      }
    end

    def rsa_key
      @rsa_key ||= OpenSSL::PKey::RSA.new(@credentials.fetch("private_key"))
    rescue OpenSSL::PKey::RSAError => e
      raise ArgumentError, "service account private_key is invalid: #{e.message}"
    end

    # rubocop:disable Metrics/MethodLength
    def exchange_jwt!(assertion)
      uri = URI.parse(@credentials.fetch("token_uri"))
      http = build_http(uri)
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request.set_form_data(
        "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion" => assertion
      )

      response = http.request(request)
      parse_token_response!(response)
    rescue JSON::ParserError
      raise DeliveryError, "Google OAuth token exchange returned invalid JSON"
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
      raise DeliveryError, "Google OAuth token exchange network error: #{e.message}"
    end
    # rubocop:enable Metrics/MethodLength

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http.write_timeout = @write_timeout if http.respond_to?(:write_timeout=)
      http
    end

    def parse_token_response!(response)
      body = JSON.parse(response.body.to_s)
      return body if response.is_a?(Net::HTTPSuccess) && body["access_token"].present?

      message = body["error_description"] || body["error"] || "token exchange failed (HTTP #{response.code})"
      raise DeliveryError, "Google OAuth token exchange failed: #{message}"
    end

    def urlsafe_encode64(value)
      Base64.urlsafe_encode64(value, padding: false)
    end
  end
end
