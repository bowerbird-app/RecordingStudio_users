# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/recording_studio_users/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests RecordingStudioUsers::Generators::InstallGenerator
  destination File.expand_path("tmp/generator", __dir__)
  setup :prepare_host_application

  def test_initializer_uses_accessible_and_host_root_callback
    run_generator %w[--skip-devise --skip-migrations]

    assert_file "config/initializers/recording_studio_users.rb" do |content|
      assert_includes content, 'config.access_actor_types = ["User"]'
      assert_includes content, "config.root_creator"
      assert_includes content, "status: :requires_resolution"
      refute_includes content, "RECORDING_STUDIO_ACCESSIBLE_BOOTSTRAP_ADMIN"
    end
  end

  def test_mounts_engine
    run_generator %w[--skip-devise --skip-migrations]

    assert_file "config/routes.rb", /mount RecordingStudioUsers::Engine/
  end

  def test_wires_root_switching_and_current_context
    run_generator %w[--skip-devise --skip-migrations]

    assert_file "app/controllers/application_controller.rb" do |content|
      assert_includes content, "include RecordingStudio::RootSwitchable::ControllerSupport"
      assert_includes content, "include RecordingStudioUsers::CurrentContext"
    end
  end

  def test_wires_tailwind_to_a_generated_source_list
    prepare_tailwind_host_files
    run_generator %w[--skip-devise --skip-migrations]

    assert_file "app/assets/tailwind/application.css" do |content|
      assert_includes content, '@import "./recording_studio_users_sources.css";'
      refute_includes content, "vendor/bundle"
    end
    assert_file "lib/tasks/recording_studio_users_tailwind.rake" do |content|
      assert_includes content, "tailwindcss:recording_studio_users_sources"
      assert_includes content, "flat_pack"
    end
    assert_file ".gitignore", %r{app/assets/tailwind/recording_studio_users_sources\.css}
  end

  def test_reports_tailwind_line_when_no_tailwind_stylesheet_exists
    output = run_generator %w[--skip-devise --skip-migrations]

    assert_includes output, '@import "./recording_studio_users_sources.css";'
    assert_no_file "lib/tasks/recording_studio_users_tailwind.rake"
  end

  private

  def prepare_host_application
    prepare_destination
    FileUtils.mkdir_p File.join(destination_root, "config")
    File.write File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n"
    FileUtils.mkdir_p File.join(destination_root, "app/controllers")
    File.write(
      File.join(destination_root, "app/controllers/application_controller.rb"),
      "class ApplicationController < ActionController::Base\nend\n"
    )
  end

  def prepare_tailwind_host_files
    FileUtils.mkdir_p File.join(destination_root, "app/assets/tailwind")
    File.write(
      File.join(destination_root, "app/assets/tailwind/application.css"),
      %(@import "tailwindcss";\n)
    )
    File.write File.join(destination_root, ".gitignore"), "/log\n"
  end
end
