# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioUser::Configuration.new
  end

  def test_defaults_match_the_public_mount_contract
    assert_equal "User", @configuration.user_class_name
    assert_equal "/recording_studio_users", @configuration.mount_path
    assert_equal "profile", @configuration.profile_route_path
    assert_equal "admin", @configuration.admin_route_path
    assert_equal "application", @configuration.layout
    assert_empty @configuration.additional_profile_attributes
  end

  def test_normalizes_configured_paths
    @configuration.mount_path = "account/"
    @configuration.profile_route_path = "/me/"
    @configuration.admin_route_path = "/user-reporting/"

    assert_equal "/account", @configuration.mount_path
    assert_equal "me", @configuration.profile_route_path
    assert_equal "user-reporting", @configuration.admin_route_path
  end

  def test_rejects_invalid_paths_and_protected_attributes
    assert_raises(ArgumentError) { @configuration.mount_path = "" }
    assert_raises(ArgumentError) { @configuration.profile_route_path = "../profile" }
    assert_raises(ArgumentError) { @configuration.admin_route_path = "admin//users" }
    assert_raises(ArgumentError) { @configuration.additional_profile_attributes = [:email] }
  end

  def test_allows_safe_additional_attributes
    @configuration.additional_profile_attributes = ["locale", :locale, "preferred_name"]

    assert_equal %i[locale preferred_name], @configuration.additional_profile_attributes
  end
end
