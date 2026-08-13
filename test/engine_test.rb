# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def test_engine_is_isolated_under_recording_studio_user
    assert_predicate RecordingStudioUser::Engine, :isolated?
  end

  def test_engine_defines_only_profile_and_admin_routes
    load File.expand_path("../config/routes.rb", __dir__)

    routes = RecordingStudioUser::Engine.routes.routes.map(&:name).compact

    assert_includes routes, "profile"
    assert_includes routes, "edit_profile"
    assert_includes routes, "admin"
    refute_includes routes, "root"
  end
end
