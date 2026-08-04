# frozen_string_literal: true

require "test_helper"

class RoutesContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_engine_root_routes_directly_to_profile
    routes = File.read(File.join(ROOT, "config/routes.rb"))

    assert_includes routes, 'root "profiles#show"'
    refute_includes routes, 'redirect("/profile")'
  end

  def test_dummy_mounts_named_route_proxies
    routes = File.read(File.join(ROOT, "test/dummy/config/routes.rb"))

    assert_includes routes, "as: :recording_studio_users"
    assert_includes routes, "as: :recording_studio_attachable"
  end

  def test_public_paths_use_mount_aware_route_proxies
    implementation = File.read(File.join(ROOT, "lib/recording_studio_users.rb"))

    assert_includes implementation, "mounted_route_proxy(:recording_studio_users)"
    assert_includes implementation, "mounted_route_proxy(:recording_studio_attachable)"
    refute_includes implementation, "Engine.routes.url_helpers.profile_path"
  end
end
