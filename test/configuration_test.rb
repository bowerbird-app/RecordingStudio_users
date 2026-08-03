# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioUsers::Configuration.new
  end

  def test_defaults_are_fail_closed_and_host_owned
    controller = Object.new

    assert_equal "application", @configuration.layout_for(controller: controller)
    assert_nil @configuration.current_actor_for(controller: controller)
    assert_nil @configuration.current_root_for(controller: controller)
    refute @configuration.authorized?(controller: controller, actor: nil, root_recording: nil)
    assert_instance_of RecordingStudioUsers::Hooks, @configuration.hooks
  end

  def test_configurable_resolvers_receive_supported_context
    actor = Object.new
    root = Object.new
    user = Object.new
    controller = Object.new
    @configuration.current_actor_resolver = ->(controller:) { actor if controller }
    @configuration.current_root_resolver = ->(controller:) { root if controller }
    @configuration.user_scope_resolver = ->(**) { [user] }
    @configuration.user_resolver = ->(email:, **) { user if email == "member@example.com" }
    @configuration.user_label_resolver = ->(user:) { "User #{user.object_id}" }
    @configuration.authorizer = ->(actor:, root_recording:, **) { actor && root_recording }

    assert_same actor, @configuration.current_actor_for(controller: controller)
    assert_same root, @configuration.current_root_for(controller: controller)
    assert_equal [user], @configuration.users_for(controller: controller)
    assert_same user, @configuration.user_for(controller: controller, email: "member@example.com")
    assert_match "User ", @configuration.user_label_for(user: user)
    assert @configuration.authorized?(controller: controller, actor: actor, root_recording: root)
  end

  def test_merge_updates_known_attributes_and_ignores_unknown_keys
    @configuration.merge!("layout" => "host", unknown_key: "ignored")

    assert_equal "host", @configuration.layout
    refute_respond_to @configuration, :unknown_key
  end

  def test_to_h_reports_registered_hooks
    @configuration.hooks.before_initialize { nil }

    assert_equal 1, @configuration.to_h.dig(:hooks_registered, :before_initialize)
  end
end
