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
      assert(!routes.include?("mount RecordingStudioUser::Engine"))
    end
  end

  def test_profile_url_path_is_configurable_without_changing_helper_name
    with_app do |directory|
      generator = build_generator(directory, profile_path: "account/profile")
      generator.install_routes

      routes = File.read(File.join(directory, "config/routes.rb"))
      assert_includes routes, "resource :profile, path: RecordingStudioUser.configuration.profile_path"
      generator.copy_initializer
      initializer = File.read(File.join(directory, "config/initializers/recording_studio_user.rb"))
      assert_includes initializer, 'config.profile_path = "account/profile"'
    end
  end

  def test_initializer_and_tailwind_sources_are_idempotent
    with_app do |directory|
      engine_view, flat_pack_component = create_tailwind_fixtures(directory)

      generator = build_generator(directory)
      2.times do
        generator.copy_initializer
        generator.add_tailwind_sources
      end

      initializer = File.read(File.join(directory, "config/initializers/recording_studio_user.rb"))
      css = File.read(File.join(directory, "app/assets/tailwind/application.css"))
      assert_includes initializer, "config.admin_registration_hook"
      assert_equal 3, css.scan("recording_studio_user").size
      assert_equal 3, css.scan(/flat_pack|flatpack/).size

      source_patterns = css.scan(/@source "([^"]+)";/).flatten
      assert_supported_source_patterns(source_patterns)
      resolved_sources = resolve_tailwind_sources(directory, source_patterns)

      assert_includes resolved_sources, engine_view
      assert_includes resolved_sources, flat_pack_component
    end
  end

  def test_copy_migrations_installs_recording_studio_user_migration
    with_app do |directory|
      generator = build_generator(directory)
      generator.copy_migrations

      copied_migrations = Dir.glob(File.join(directory, "db/migrate/*create_recording_studio_user_users*.rb"))
      assert_equal 1, copied_migrations.size
    end
  end

  def test_add_tailwind_sources_skips_when_tailwind_is_not_installed
    with_app do |directory|
      generator = build_generator(directory)
      tailwind_path = File.join(directory, "app/assets/tailwind/application.css")
      FileUtils.rm(tailwind_path)

      generator.add_tailwind_sources

      assert(!File.exist?(tailwind_path))
    end
  end

  def test_installer_does_not_generate_host_admin_or_access_resources
    source = File.read(File.expand_path(
                         "../lib/generators/recording_studio_user/install/install_generator.rb",
                         __dir__
                       ))

    assert(!source.include?("AdminRoot"))
    assert(!source.include?("grant_access"))
    assert(!source.include?("recording_studio_admin_for"))
    assert(!source.include?("RecordingStudioAccessible"))
  end

  private

  def create_tailwind_fixtures(directory)
    paths = [
      "vendor/bundle/ruby/3.3.0/gems/recording_studio_user-0.1.0/app/views/profiles/show.html.erb",
      "vendor/bundle/ruby/3.3.0/gems/flat_pack-0.1.129/app/components/button/component.html.erb"
    ].map { |path| File.join(directory, path) }

    paths.each do |path|
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)
    end

    paths
  end

  def assert_supported_source_patterns(source_patterns)
    assert_includes source_patterns,
                    "../../../../../../usr/local/bundle/ruby/**/gems/recording_studio_user-*/app/views/**/*.erb"
    assert_includes source_patterns,
                    "../../../../../../usr/local/bundle/ruby/**/bundler/gems/" \
                    "recording_studio_user-*/app/views/**/*.erb"
    assert_includes source_patterns,
                    "../../../../../../usr/local/bundle/ruby/**/gems/flat_pack-*/app/components/**/*.{rb,erb}"
    assert_includes source_patterns,
                    "../../../../../../usr/local/bundle/ruby/**/bundler/gems/" \
                    "flatpack-*/app/components/**/*.{rb,erb}"
  end

  def resolve_tailwind_sources(directory, source_patterns)
    stylesheet_directory = File.join(directory, "app/assets/tailwind")
    source_patterns.flat_map do |pattern|
      Dir.glob(File.expand_path(pattern, stylesheet_directory))
    end
  end
end
