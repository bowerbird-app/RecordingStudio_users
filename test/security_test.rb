# frozen_string_literal: true

require "test_helper"

class SecurityTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  FORBIDDEN_OUTPUTS = %w[
    signed_blob_id
    blob_key
    service_url
    encrypted_password
    reset_password_token
    confirmation_token
    unlock_token
  ].freeze

  def test_picker_payload_does_not_expose_topology_or_storage_identifiers
    controller = File.read(File.join(ROOT, "app/controllers/recording_studio_users/users_controller.rb"))

    FORBIDDEN_OUTPUTS.each { |field| refute_includes controller, "#{field}:" }
    refute_includes controller, "user_root"
    refute_includes controller, "profile_recording"
    refute_includes controller, "attachment"
  end

  def test_event_metadata_sanitizer_blocks_security_fields
    pattern = RecordingStudioUsers::Services::LogUserEvent::SENSITIVE_KEYS

    FORBIDDEN_OUTPUTS.each { |field| assert_match pattern, field }
  end

  def test_request_input_is_not_constantized
    production_sources = Dir[File.join(ROOT, "{app,lib}/**/*.rb")].map { |path| File.read(path) }.join("\n")

    refute_match(/params.*constantize/, production_sources)
    refute_match(/params.*safe_constantize/, production_sources)
  end

  def test_avatar_controller_does_not_create_or_purge_blobs
    controller = File.read(File.join(ROOT, "app/controllers/recording_studio_users/profiles_controller.rb"))

    refute_includes controller, "ActiveStorage::Blob"
    refute_includes controller, ".purge"
    assert_includes controller, "params.require(:signed_blob_id)"
  end
end
