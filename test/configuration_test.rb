# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioUsers::Configuration.new
  end

  def test_defaults_are_fail_closed_and_host_owned
    controller = Object.new
    user = Struct.new(:id).new("user-1")

    assert_equal "application", @configuration.layout_for(controller: controller)
    assert_equal "User", @configuration.user_class_name
    assert_nil @configuration.current_actor_for(controller: controller)
    assert_nil @configuration.current_root_for(controller: controller)
    assert_equal user, @configuration.provisioning_actor_for(user: user)
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
    @configuration.provisioning_actor_resolver = ->(user:, **) { user }
    @configuration.authorizer = ->(actor:, root_recording:, **) { actor && root_recording }

    assert_same actor, @configuration.current_actor_for(controller: controller)
    assert_same root, @configuration.current_root_for(controller: controller)
    assert_equal [user], @configuration.users_for(controller: controller)
    assert_same user, @configuration.user_for(controller: controller, email: "member@example.com")
    assert_match "User ", @configuration.user_label_for(user: user)
    assert_same user, @configuration.provisioning_actor_for(user: user, controller: controller)
    assert @configuration.authorized?(controller: controller, actor: actor, root_recording: root)
  end

  def test_user_class_constantizes_configured_name
    @configuration.user_class_name = "String"

    assert_equal String, @configuration.user_class
  end

  def test_user_class_raises_for_invalid_constant
    @configuration.user_class_name = "NotARealClass"

    error = assert_raises(ArgumentError) { @configuration.user_class }
    assert_includes error.message, "could not be constantized"
  end

  def test_merge_updates_known_attributes_and_ignores_unknown_keys
    @configuration.merge!("layout" => "host", unknown_key: "ignored")

    assert_equal "host", @configuration.layout
    refute_respond_to @configuration, :unknown_key
  end

  def test_default_user_label_handles_deleted_users_and_prefers_name
    named_user = Struct.new(:name, :email).new("Member Name", "member@example.com")
    unnamed_user = Struct.new(:name, :email).new(nil, "member@example.com")

    assert_equal "Member Name", @configuration.user_label_for(user: named_user)
    assert_equal "member@example.com", @configuration.user_label_for(user: unnamed_user)
    assert_equal "Deleted user", @configuration.user_label_for(user: nil)
  end

  def test_to_h_reports_registered_hooks
    @configuration.hooks.before_initialize { nil }

    assert_equal 1, @configuration.to_h.dig(:hooks_registered, :before_initialize)
  end
end
