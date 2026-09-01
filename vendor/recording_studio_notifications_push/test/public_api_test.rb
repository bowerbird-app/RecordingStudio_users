# frozen_string_literal: true

require "test_helper"

class PublicApiTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioNotificationsPush.instance_variable_get(:@configuration)
    @original_adapter = RecordingStudioNotificationsPush.instance_variable_get(:@adapter)
    RecordingStudioNotificationsPush.reset_configuration!
  end

  def teardown
    RecordingStudioNotificationsPush.instance_variable_set(:@configuration, @original_configuration)
    RecordingStudioNotificationsPush.instance_variable_set(:@adapter, @original_adapter)
  end

  def test_configure_supports_defaults_and_overrides
    returned = RecordingStudioNotificationsPush.configure do |config|
      config.firebase_project_id = "project-from-block"
    end

    assert_same RecordingStudioNotificationsPush.configuration, returned
    assert_equal "project-from-block", returned.firebase_project_id
    assert_same returned, RecordingStudioNotificationsPush.config
  end

  def test_register_delegates_push_adapter_to_parent_registry
    registration = nil
    implementation = lambda do |channel, adapter|
      registration = [channel, adapter]
      adapter
    end

    RecordingStudioNotifications.stub(:register_channel, implementation) do
      result = RecordingStudioNotificationsPush.register!

      assert_equal :push, registration.first
      assert_instance_of RecordingStudioNotificationsPush::FcmAdapter, registration.last
      assert_same registration.last, result
    end
  end

  def test_version_and_engine_are_public
    assert_equal "0.2.0", RecordingStudioNotificationsPush::VERSION
    assert_kind_of Class, RecordingStudioNotificationsPush::Engine
  end

  def test_engine_registers_channel_from_rails_prepare_callback
    prepare_callbacks = []
    config = Object.new
    config.define_singleton_method(:to_prepare) { |&block| prepare_callbacks << block }
    initializer = RecordingStudioNotificationsPush::Engine.initializers.find do |candidate|
      candidate.name == "recording_studio_notifications_push.register_channel"
    end

    RecordingStudioNotificationsPush::Engine.stub(:config, config) { initializer.block.call }

    called = false
    RecordingStudioNotificationsPush.stub(:register!, -> { called = true }) { prepare_callbacks.fetch(0).call }

    assert called
  end

  def test_engine_registers_pwa_service_worker_extension_when_available
    prepare_callbacks = []
    config = Object.new
    config.define_singleton_method(:to_prepare) { |&block| prepare_callbacks << block }
    initializer = RecordingStudioNotificationsPush::Engine.initializers.find do |candidate|
      candidate.name == "recording_studio_notifications_push.register_pwa_service_worker"
    end

    RecordingStudioNotificationsPush::Engine.stub(:config, config) { initializer.block.call }

    registered = nil
    fake_pwa = Module.new do
      define_singleton_method(:register_service_worker_extension) do |partial|
        registered = partial
      end
    end

    previously_defined = Object.const_defined?(:RecordingStudioPwa)
    previous = Object.const_get(:RecordingStudioPwa) if previously_defined
    silence_warnings { Object.const_set(:RecordingStudioPwa, fake_pwa) }
    begin
      prepare_callbacks.fetch(0).call
    ensure
      Object.send(:remove_const, :RecordingStudioPwa)
      Object.const_set(:RecordingStudioPwa, previous) if previously_defined
    end

    assert_equal "recording_studio_notifications_push/service_worker_push", registered
  end

  def silence_warnings
    verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = verbose
  end
end
