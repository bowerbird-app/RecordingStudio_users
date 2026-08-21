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
    refute_includes routes, "admin_user"
    refute_includes routes, "edit_admin_user"
    refute_includes routes, "root"
  end

  def test_profile_authorization_uses_accessible_not_current_user_acl
    controller = File.read(File.expand_path("../app/controllers/recording_studio_user/profiles_controller.rb", __dir__))
    profile = File.read(File.expand_path("../app/models/recording_studio_user/profile.rb", __dir__))
    people = File.read(File.expand_path("../app/models/recording_studio_user/people.rb", __dir__))
    admin = File.read(File.expand_path("../app/controllers/recording_studio_user/admin/users_controller.rb", __dir__))

    assert_includes profile, "RecordingStudio.enable_capability(:accessible, on: self)"
    refute_includes people, "enable_capability(:accessible"
    assert_includes controller, "RecordingStudioAccessible.authorized?"
    refute_includes controller, "can_access?"
    refute_includes controller, "@user.update"
    refute_includes admin, "user.admin?"
  end
end
