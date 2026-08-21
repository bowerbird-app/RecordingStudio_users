# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    RecordingStudioUsers.reset_configuration!
  end

  def teardown
    RecordingStudioUsers.reset_configuration!
  end

  def test_root_creator_is_required
    error = assert_raises(RecordingStudioUsers::ConfigurationError) do
      RecordingStudioUsers.configuration.create_root(name: "Studio", actor: Object.new)
    end

    assert_equal "Configure root_creator before creating a workspace", error.message
  end

  def test_root_creator_receives_only_supported_keywords
    received_name = nil
    RecordingStudioUsers.configuration.root_creator = lambda do |name:|
      received_name = name
      :workspace
    end

    result = RecordingStudioUsers.configuration.create_root(name: "Studio", actor: Object.new)

    assert_equal :workspace, result
    assert_equal "Studio", received_name
  end

  def test_user_finder_normalizes_email
    received_email = nil
    RecordingStudioUsers.configuration.user_finder = lambda do |email:|
      received_email = email
      :user
    end

    assert_equal :user, RecordingStudioUsers.configuration.find_user(email: "PERSON@EXAMPLE.COM")
    assert_equal "PERSON@EXAMPLE.COM", received_email
  end
end
