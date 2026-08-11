# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioUser::Configuration.new
  end

  def test_defaults_use_the_gem_owned_user_and_host_layout
    assert_equal "RecordingStudioUser::User", @configuration.user_model
    assert_equal "profile", @configuration.profile_path
    assert_equal "application", @configuration.default_layout
    assert_empty @configuration.additional_permitted_profile_attributes
  end

  def test_profile_parameters_are_deliberately_limited
    @configuration.additional_permitted_profile_attributes = %w[locale]

    assert_equal %i[first_name last_name time_zone locale], @configuration.permitted_profile_attributes
  end

  def test_merge_updates_known_values_and_ignores_unknown_values
    @configuration.merge!("default_layout" => "host", "unknown" => true)

    assert_equal "host", @configuration.default_layout
    refute_respond_to @configuration, :unknown
  end

  def test_admin_registration_hook_is_replaceable
    called = false
    @configuration.admin_registration_hook = -> { called = true }

    @configuration.register_admin!

    assert called
  end
end
