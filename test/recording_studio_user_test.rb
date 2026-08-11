# frozen_string_literal: true

require "test_helper"

class RecordingStudioUserTest < Minitest::Test
  def test_engine_and_release_metadata_exist
    assert_equal "0.1.2", RecordingStudioUser::VERSION
    assert_kind_of Class, RecordingStudioUser::Engine
  end

  def test_user_class_resolves_the_configured_model
    original = RecordingStudioUser.configuration.user_model
    RecordingStudioUser.configuration.user_model = "String"

    assert_equal String, RecordingStudioUser.user_class
  ensure
    RecordingStudioUser.configuration.user_model = original
  end

  def test_engine_has_no_browser_landing_page
    refute File.exist?(File.expand_path("../app/controllers/recording_studio_user/home_controller.rb", __dir__))
    refute File.exist?(File.expand_path("../app/views/recording_studio_user/home/index.html.erb", __dir__))
  end
end
