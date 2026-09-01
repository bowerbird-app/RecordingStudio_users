# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @original = {
      "FIREBASE_API_KEY" => ENV.fetch("FIREBASE_API_KEY", nil),
      "FIREBASE_APP_ID" => ENV.fetch("FIREBASE_APP_ID", nil),
      "FIREBASE_AUTH_DOMAIN" => ENV.fetch("FIREBASE_AUTH_DOMAIN", nil),
      "FIREBASE_MESSAGING_SENDER_ID" => ENV.fetch("FIREBASE_MESSAGING_SENDER_ID", nil),
      "FIREBASE_PROJECT_ID" => ENV.fetch("FIREBASE_PROJECT_ID", nil),
      "FIREBASE_STORAGE_BUCKET" => ENV.fetch("FIREBASE_STORAGE_BUCKET", nil),
      "FIREBASE_VAPID_PUBLIC_KEY" => ENV.fetch("FIREBASE_VAPID_PUBLIC_KEY", nil),
      "FIREBASE_SERVICE_ACCOUNT_JSON" => ENV.fetch("FIREBASE_SERVICE_ACCOUNT_JSON", nil)
    }
  end

  def teardown
    @original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def test_defaults_include_push_channel
    configuration = RecordingStudioNotificationsPush::Configuration.new

    assert_equal :push, configuration.channel
    assert_equal 5, configuration.open_timeout
    assert_equal 15, configuration.read_timeout
  end

  def test_loads_firebase_web_config_from_env
    ENV["FIREBASE_API_KEY"] = "api-key"
    ENV["FIREBASE_APP_ID"] = "app-id"
    ENV["FIREBASE_AUTH_DOMAIN"] = "example.firebaseapp.com"
    ENV["FIREBASE_MESSAGING_SENDER_ID"] = "123"
    ENV["FIREBASE_PROJECT_ID"] = "demo-project"
    ENV["FIREBASE_STORAGE_BUCKET"] = "demo-project.appspot.com"
    ENV["FIREBASE_VAPID_PUBLIC_KEY"] = "vapid-public"
    ENV["FIREBASE_SERVICE_ACCOUNT_JSON"] = '{"type":"service_account"}'

    configuration = RecordingStudioNotificationsPush::Configuration.new

    assert_equal "demo-project", configuration.firebase_project_id
    assert_equal "vapid-public", configuration.vapid_public_key
    assert_equal "api-key", configuration.firebase_web_config[:apiKey]
    assert_equal "app-id", configuration.firebase_web_config[:appId]
    assert_equal "123", configuration.firebase_web_config[:messagingSenderId]
    assert configuration.service_account_configured?
  end

  def test_merge_updates_known_keys
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.merge!("firebase_project_id" => "merged-project", unknown: true)

    assert_equal "merged-project", configuration.firebase_project_id
    refute_respond_to configuration, :unknown
  end

  def test_to_h_hides_service_account_secret
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.firebase_service_account_json = '{"private_key":"SECRET"}'
    hash = configuration.to_h

    assert_equal true, hash[:firebase_service_account_configured]
    refute_includes hash.values.map(&:to_s).join, "SECRET"
  end

  def test_web_push_client_ready_when_required_firebase_values_present
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.firebase_web_config = {
      apiKey: "key",
      appId: "app",
      projectId: "project",
      messagingSenderId: "123"
    }
    configuration.vapid_public_key = "vapid"

    assert configuration.web_push_client_ready?
  end

  def test_web_push_client_ready_false_when_vapid_missing
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.firebase_web_config = {
      apiKey: "key",
      appId: "app",
      projectId: "project",
      messagingSenderId: "123"
    }
    configuration.vapid_public_key = nil

    refute configuration.web_push_client_ready?
  end

  def test_web_push_client_ready_accepts_string_keys
    configuration = RecordingStudioNotificationsPush::Configuration.new
    configuration.firebase_web_config = {
      "apiKey" => "key",
      "appId" => "app",
      "projectId" => "project",
      "messagingSenderId" => "123"
    }
    configuration.vapid_public_key = "vapid"

    assert configuration.web_push_client_ready?
  end
end
