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
    assert @configuration.require_password_confirmation
    assert_predicate @configuration, :require_password_confirmation?
    assert_empty @configuration.omniauth_providers
    assert @configuration.omniauth_create_account
    assert_predicate @configuration, :omniauth_create_account?
    refute_predicate @configuration, :omniauth_configured?
  end

  def test_require_password_confirmation_casts_like_other_flags
    @configuration.require_password_confirmation = false
    refute_predicate @configuration, :require_password_confirmation?

    @configuration.require_password_confirmation = "true"
    assert_predicate @configuration, :require_password_confirmation?
  end

  def test_omniauth_flags_and_providers
    @configuration.omniauth_create_account = false
    refute_predicate @configuration, :omniauth_create_account?

    @configuration.omniauth_create_account = "true"
    assert_predicate @configuration, :omniauth_create_account?

    @configuration.omniauth_providers = {
      "google_oauth2" => { "client_id" => "id", "client_secret" => "secret" }
    }
    assert_equal({ google_oauth2: { client_id: "id", client_secret: "secret" } }, @configuration.omniauth_providers)
    assert_predicate @configuration, :omniauth_configured?
    assert_predicate @configuration, :google_oauth2_configured?
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

  def test_mounted_admin_path_uses_configured_paths
    original_config = RecordingStudioUser.config
    RecordingStudioUser.instance_variable_set(:@config, @configuration)
    @configuration.mount_path = "/account"
    @configuration.admin_route_path = "user-reporting"

    assert_equal "/account/user-reporting", RecordingStudioUser.mounted_admin_path
  ensure
    RecordingStudioUser.instance_variable_set(:@config, original_config)
  end
end
