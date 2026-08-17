# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/recording_studio_user/install/install_generator"

class RecordingStudioUserInstallGeneratorTest < Rails::Generators::TestCase
  tests RecordingStudioUser::Generators::InstallGenerator
  destination File.expand_path("../../tmp/generators", __dir__)

  setup do
    prepare_destination
    FileUtils.mkdir_p(File.join(destination_root, "config/initializers"))
    FileUtils.mkdir_p(File.join(destination_root, "app/assets/tailwind"))
    File.write(File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
    File.write(File.join(destination_root, "app/assets/tailwind/application.css"), "@import \"tailwindcss\";\n")
  end

  test "installs the mount, initializer, and tailwind sources idempotently" do
    original_root = Rails.root
    generator_root = Pathname.new(destination_root)
    Rails.define_singleton_method(:root) { generator_root }

    run_generator

    first_routes = File.read(File.join(destination_root, "config/routes.rb"))
    first_initializer = File.read(File.join(destination_root, "config/initializers/recording_studio_user.rb"))
    first_tailwind = File.read(File.join(destination_root, "app/assets/tailwind/application.css"))

    run_generator

    assert_equal first_routes, File.read(File.join(destination_root, "config/routes.rb"))
    assert_equal first_initializer, File.read(File.join(destination_root, "config/initializers/recording_studio_user.rb"))
    assert_equal first_tailwind, File.read(File.join(destination_root, "app/assets/tailwind/application.css"))

    assert_equal 1, first_routes.scan("mount RecordingStudioUser::Engine").size
    assert_includes first_routes, "as: :recording_studio_users"
    assert_includes first_routes, "RecordingStudioUser.config.mount_path"
    assert_includes first_initializer, "Route configuration must load before Rails draws routes."
    assert_operator first_tailwind.scan("recording_studio_user").size, :>=, 1
    assert_includes first_tailwind, "flatpack"
    refute_includes first_routes, "devise_for"
    refute File.exist?(File.join(destination_root, "app/models/user.rb"))
  ensure
    Rails.define_singleton_method(:root) { original_root }
  end
end
