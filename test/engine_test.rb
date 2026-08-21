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

  def test_first_owner_uses_bootstrap_on_profile_without_authorizer_swap
    directory = File.read(File.expand_path("../lib/recording_studio_user/directory.rb", __dir__))
    access = File.read(File.expand_path("../lib/recording_studio_user/profile_access.rb", __dir__))

    assert_includes directory, "RecordingStudioAccessible.bootstrap_owner_access!("
    assert_includes directory, "recording: recording"
    assert_includes directory, "actor: user"
    assert_includes access, "RecordingStudioAccessible.grant_access"
    refute_includes directory, "access_management_authorizer"
    refute_includes access, "access_management_authorizer"
    refute_includes directory, "AccessCreationContext"
    refute_includes access, "AccessCreationContext"
    refute_includes directory, "grant_first_owner"
    refute_includes access, "first_owner_retry?"
    refute_includes access, "AUTHORIZER_MUTEX"
    refute_includes access, "ensure_owner_access!"
    refute_includes directory, "bootstrap_owner_access!(recording: people_root"
  end
end
