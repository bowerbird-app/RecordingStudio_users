# frozen_string_literal: true

require "test_helper"

module HostViewOverrideHelpers
  FIXTURE_ROOT = RecordingStudioUser::Engine.root.join("test/fixtures/host_view_overrides").freeze
  HOST_VIEWS = Rails.root.join("app/views").freeze

  def install_host_override!(relative)
    source = FIXTURE_ROOT.join(relative)
    destination = HOST_VIEWS.join(relative)
    FileUtils.mkdir_p(destination.dirname)
    FileUtils.cp(source, destination)
    clear_view_resolver_cache!
  end

  def remove_host_override!(relative)
    path = HOST_VIEWS.join(relative)
    FileUtils.rm_f(path)
    dir = path.dirname
    while dir != HOST_VIEWS && dir.directory? && dir.children.empty?
      dir.rmdir
      dir = dir.dirname
    end
    clear_view_resolver_cache!
  end

  def clear_view_resolver_cache!
    ActionController::Base.view_paths.each do |resolver|
      resolver.clear_cache if resolver.respond_to?(:clear_cache)
    end
  end
end

# Host app/views must win over the gem for auth screens. Overrides live in a
# fixture tree and are copied into the dummy app/views only for these tests so
# they never leak into other suites.
class HostViewOverrideTest < ActionDispatch::IntegrationTest
  include HostViewOverrideHelpers

  OVERRIDES = [
    "recording_studio_user/auth/registrations/new.html.erb",
    "recording_studio_user/auth/passwords/edit.html.erb"
  ].freeze

  setup do
    OVERRIDES.each { |relative| install_host_override!(relative) }
  end

  teardown do
    OVERRIDES.each { |relative| remove_host_override!(relative) }
  end

  test "host registration new view renders instead of the gem view" do
    get new_user_registration_path

    assert_response :success
    assert_select "#host-registration-new-override", text: "Host sign-up override"
    refute_includes response.body, "Continue with email"
    refute_includes response.body, "Already have one?"
  end

  test "host password edit view renders instead of the gem view" do
    get edit_user_password_path(reset_password_token: "reset-token")

    assert_response :success
    assert_select "#host-password-edit-override", text: "Host password-edit override"
    refute_includes response.body, "Choose a new password"
    refute_includes response.body, "Save password"
  end

  test "signup view paths prefer host then users over other gems" do
    RecordingStudioUser::Engine.prefer_signup_view_paths!

    paths = ActionController::Base.view_paths.map(&:to_s)
    host = Rails.root.join("app/views").to_s
    users = RecordingStudioUser::Engine.root.join("app/views").to_s

    assert_equal host, paths[0]
    assert_equal users, paths[1]
  end
end

# Separate class so no override files exist and the gem templates resolve cleanly.
class HostViewOverrideAbsentTest < ActionDispatch::IntegrationTest
  include HostViewOverrideHelpers

  setup do
    remove_host_override!("recording_studio_user/auth/registrations/new.html.erb")
    remove_host_override!("recording_studio_user/auth/passwords/edit.html.erb")
  end

  test "without a host override the gem registration new view still renders" do
    get new_user_registration_path

    assert_response :success
    assert_select "button[type='submit']", text: "Continue with email"
    assert_includes response.body, "Already have one?"
    assert_select "#host-registration-new-override", count: 0
  end
end
