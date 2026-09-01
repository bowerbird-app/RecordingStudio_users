# frozen_string_literal: true

require "test_helper"
require "json"
require "openssl"
require "base64"

class GoogleAccessTokenTest < Minitest::Test
  def setup
    @rsa = OpenSSL::PKey::RSA.new(2048)
    @service_account = {
      "type" => "service_account",
      "project_id" => "demo-project",
      "private_key_id" => "key-id",
      "private_key" => @rsa.to_pem,
      "client_email" => "firebase-adminsdk@demo-project.iam.gserviceaccount.com",
      "client_id" => "123456789",
      "token_uri" => "https://oauth2.googleapis.com/token"
    }
  end

  def test_builds_and_exchanges_jwt_for_access_token
    provider = RecordingStudioNotificationsPush::GoogleAccessToken.new(
      service_account_json: JSON.generate(@service_account)
    )

    captured_assertion = nil
    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:write_timeout=) { |_| }
    fake_http.define_singleton_method(:request) do |request|
      captured_assertion = request.body[/assertion=([^&]+)/, 1]
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@read, true)
      response.define_singleton_method(:body) do
        JSON.generate("access_token" => "ya29.test-token", "expires_in" => 3600, "token_type" => "Bearer")
      end
      response
    end

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      token = provider.fetch
      assert_equal "ya29.test-token", token
    end

    assert captured_assertion
    decoded_assertion = URI.decode_www_form_component(captured_assertion)
    header_b64, claims_b64, signature_b64 = decoded_assertion.split(".")
    claims = JSON.parse(Base64.urlsafe_decode64(claims_b64))
    assert_equal @service_account.fetch("client_email"), claims.fetch("iss")
    assert_equal "https://www.googleapis.com/auth/firebase.messaging", claims.fetch("scope")

    signing_input = "#{header_b64}.#{claims_b64}"
    signature = Base64.urlsafe_decode64(signature_b64)
    assert @rsa.verify(OpenSSL::Digest.new("SHA256"), signature, signing_input)
  end

  def test_rejects_invalid_service_account_json
    assert_raises(ArgumentError) do
      RecordingStudioNotificationsPush::GoogleAccessToken.new(service_account_json: "{not-json")
    end
  end

  def test_caches_token_until_expiry
    provider = RecordingStudioNotificationsPush::GoogleAccessToken.new(
      service_account_json: @service_account
    )

    calls = 0
    fake_http = Object.new
    fake_http.define_singleton_method(:use_ssl=) { |_| }
    fake_http.define_singleton_method(:open_timeout=) { |_| }
    fake_http.define_singleton_method(:read_timeout=) { |_| }
    fake_http.define_singleton_method(:write_timeout=) { |_| }
    fake_http.define_singleton_method(:request) do |_request|
      calls += 1
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@read, true)
      response.define_singleton_method(:body) do
        JSON.generate("access_token" => "cached-token", "expires_in" => 3600)
      end
      response
    end

    Net::HTTP.stub(:new, ->(*) { fake_http }) do
      assert_equal "cached-token", provider.fetch
      assert_equal "cached-token", provider.fetch
    end

    assert_equal 1, calls
  end
end
