# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioNotificationsPush.instance_variable_get(:@configuration)
    RecordingStudioNotificationsPush.reset_configuration!
  end

  def teardown
    RecordingStudioNotificationsPush.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_load_config_merges_config_sources
    xcfg = Struct.new(:recording_studio_notifications_push).new({ firebase_project_id: "from-x" })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { vapid_public_key: "from-yaml" }
      end
    end.new(app_config)

    find_initializer("recording_studio_notifications_push.load_config").block.call(app)

    assert_equal "from-yaml", RecordingStudioNotificationsPush.configuration.vapid_public_key
    assert_equal "from-x", RecordingStudioNotificationsPush.configuration.firebase_project_id
  end

  def test_register_channel_initializer_exists
    initializer = find_initializer("recording_studio_notifications_push.register_channel")
    refute_nil initializer
  end

  def test_pwa_initializer_exists
    initializer = find_initializer("recording_studio_notifications_push.register_pwa_service_worker")
    refute_nil initializer
  end

  private

  def find_initializer(name)
    RecordingStudioNotificationsPush::Engine.initializers.find { |entry| entry.name == name }
  end
end
