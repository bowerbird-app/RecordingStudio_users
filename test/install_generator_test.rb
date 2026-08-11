# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_user/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  def with_app
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, "config"))
      FileUtils.mkdir_p(File.join(directory, "app/assets/tailwind"))
      File.write(File.join(directory, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
      File.write(File.join(directory, "app/assets/tailwind/application.css"), "@import \"tailwindcss\";\n")
      yield directory
    end
  end

  def build_generator(directory, options = {})
    RecordingStudioUser::Generators::InstallGenerator.new([], options, destination_root: directory)
  end

  def test_installs_profile_and_devise_routes_idempotently
    with_app do |directory|
      generator = build_generator(directory)
      2.times { generator.install_routes }

      routes = File.read(File.join(directory, "config/routes.rb"))
      assert_equal 1, routes.scan("# RecordingStudioUser routes").size
      assert_includes routes, "devise_for :users"
      assert_includes routes, 'sessions: "recording_studio_user/devise/sessions"'
      assert_includes routes, "resource :profile"
      refute_includes routes, "mount RecordingStudioUser::Engine"
    end
  end

  def test_profile_url_path_is_configurable_without_changing_helper_name
    with_app do |directory|
      build_generator(directory, profile_path: "account/profile").install_routes

      routes = File.read(File.join(directory, "config/routes.rb"))
      assert_includes routes, 'resource :profile, path: "account/profile"'
    end
  end

  def test_initializer_and_tailwind_sources_are_idempotent
    with_app do |directory|
      generator = build_generator(directory)
      2.times do
        generator.copy_initializer
        generator.add_tailwind_sources
      end

      initializer = File.read(File.join(directory, "config/initializers/recording_studio_user.rb"))
      css = File.read(File.join(directory, "app/assets/tailwind/application.css"))
      assert_includes initializer, "config.admin_registration_hook"
      assert_equal 2, css.scan("recording_studio_user").size
      assert_equal 2, css.scan("flat_pack").size
    end
  end

  def test_installer_does_not_generate_host_admin_or_access_resources
    source = File.read(File.expand_path(
      "../lib/generators/recording_studio_user/install/install_generator.rb",
      __dir__
    ))

    refute_includes source, "AdminRoot"
    refute_includes source, "grant_access"
    refute_includes source, "recording_studio_admin_for"
    refute_includes source, "RecordingStudioAccessible"
  end
end
