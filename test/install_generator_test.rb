# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_users/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  INSTALL_TEMPLATE_PATH = File.expand_path(
    "../lib/generators/recording_studio_users/install/templates/INSTALL.md",
    __dir__
  )

  def with_temp_app
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/assets/tailwind"))
      yield dir
    end
  end

  def build_generator(destination_root, options = {})
    RecordingStudioUsers::Generators::InstallGenerator.new(
      [],
      options,
      destination_root: destination_root
    )
  end

  def test_mount_engine_uses_configured_mount_path
    generator = build_generator("/tmp", mount_path: "/addons/recording")
    routes = []

    generator.stub(:route, ->(value) { routes << value }) do
      generator.mount_engine
    end

    assert_equal [
      "mount RecordingStudioUsers::Engine, at: \"/addons/recording\", as: :recording_studio_users",
      "mount RecordingStudioAttachable::Engine, at: \"/recording_studio_attachable\", " \
      "as: :recording_studio_attachable"
    ], routes
  end

  def test_install_attachable_invokes_dependency_installer
    generator = build_generator("/tmp")
    invocations = []

    generator.stub(:invoke, ->(name) { invocations << name }) do
      generator.install_attachable
    end

    assert_equal ["recording_studio_attachable:install"], invocations
  end

  def test_mount_engine_adds_missing_attachable_mount_on_repeated_install
    with_temp_app do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(
        File.join(dir, "config/routes.rb"),
        "mount RecordingStudioUsers::Engine, at: \"/account\", as: :recording_studio_users\n"
      )
      routes = []
      generator = build_generator(dir)

      generator.stub(:route, ->(value) { routes << value }) { generator.mount_engine }

      assert_equal [
        "mount RecordingStudioAttachable::Engine, at: \"/recording_studio_attachable\", " \
        "as: :recording_studio_attachable"
      ], routes
    end
  end

  def test_add_tailwind_source_injects_engine_and_flatpack_sources
    with_temp_app do |dir|
      css_path = File.join(dir, "app/assets/tailwind/application.css")
      File.write(css_path, "@import \"tailwindcss\";\n")

      generator = build_generator(dir)

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, nil) do
          generator.add_tailwind_source
        end
      end

      css = File.read(css_path)
      assert_tailwind_sources_present(css)
    end
  end

  def test_add_tailwind_source_does_not_duplicate_existing_entries
    with_temp_app do |dir|
      css_path = File.join(dir, "app/assets/tailwind/application.css")
      File.write(css_path, <<~CSS)
        @import "tailwindcss";
        @source "../../vendor/bundle/**/recording_studio_users/app/views/**/*.erb";
        @source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/recording_studio_users-*/app/views/**/*.erb";
        @source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";
        @source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";
      CSS

      generator = build_generator(dir)

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, nil) do
          generator.add_tailwind_source
        end
      end

      css = File.read(css_path)
      assert_tailwind_sources_present(css)
      assert_tailwind_sources_count(css, 1)
    end
  end

  def test_add_tailwind_source_reports_missing_tailwind_config
    with_temp_app do |dir|
      FileUtils.rm_rf(File.join(dir, "app/assets/tailwind"))
      generator = build_generator(dir)
      messages = []

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, ->(message, color = nil) { messages << [message, color] }) do
          generator.add_tailwind_source
        end
      end

      assert_includes messages, ["Tailwind CSS not detected. Skipping Tailwind configuration.", :yellow]
      assert_includes messages, ["If you use Tailwind, add these lines to your Tailwind CSS config:", :yellow]
      tailwind_source_lines.each do |line|
        assert_includes messages, ["  #{line}", :yellow]
      end
    end
  end

  def test_add_tailwind_source_reports_manual_configuration_when_import_is_missing
    with_temp_app do |dir|
      css_path = File.join(dir, "app/assets/tailwind/application.css")
      File.write(css_path, "@source \"../local/**/*.erb\";\n")
      generator = build_generator(dir)
      messages = []

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, ->(message, color = nil) { messages << [message, color] }) do
          generator.add_tailwind_source
        end
      end

      assert_equal "@source \"../local/**/*.erb\";\n", File.read(css_path)
      assert_includes messages, ["Could not find @import \"tailwindcss\" in your Tailwind config.", :yellow]
      assert_includes messages, ["Please manually add these lines to your Tailwind CSS config:", :yellow]
      tailwind_source_lines.each do |line|
        assert_includes messages, ["  #{line}", :yellow]
      end
    end
  end

  def test_show_readme_displays_install_guide_for_invoke_behavior
    generator = build_generator("/tmp")
    shown_templates = []

    generator.stub(:behavior, :invoke) do
      generator.stub(:readme, ->(template) { shown_templates << template }) do
        generator.show_readme
      end
    end

    assert_equal ["INSTALL.md"], shown_templates
  end

  def test_add_javascript_configures_importmap_and_stimulus_idempotently
    with_temp_app do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      FileUtils.mkdir_p(File.join(dir, "app/javascript/controllers"))
      File.write(File.join(dir, "config/importmap.rb"), "pin \"application\"\n")
      File.write(
        File.join(dir, "app/javascript/controllers/index.js"),
        "import { application } from \"controllers/application\"\n"
      )
      generator = build_generator(dir)

      generator.add_javascript
      generator.add_javascript

      importmap = File.read(File.join(dir, "config/importmap.rb"))
      controllers = File.read(File.join(dir, "app/javascript/controllers/index.js"))
      assert_equal 1, importmap.scan("pin_all_from RecordingStudioUsers::Engine.root").size
      assert_equal 1, controllers.scan(
        'eagerLoadRecordingStudioUsersControllersFrom("controllers/recording_studio_users", application)'
      ).size
      assert_includes controllers, "@hotwired/stimulus-loading"
    end
  end

  def test_add_javascript_reports_manual_setup_when_host_files_are_missing
    with_temp_app do |dir|
      messages = []
      generator = build_generator(dir)

      generator.stub(:say, ->(message, color = nil) { messages << [message, color] }) do
        generator.add_javascript
      end

      assert_includes messages,
                      ["config/importmap.rb was not found. Add this RecordingStudioUsers JavaScript " \
                       "configuration manually:", :yellow]
      assert_includes messages,
                      ["app/javascript/controllers/index.js was not found. Add this RecordingStudioUsers " \
                       "JavaScript configuration manually:", :yellow]
    end
  end

  def test_add_javascript_recognizes_existing_single_quoted_loader
    with_temp_app do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      FileUtils.mkdir_p(File.join(dir, "app/javascript/controllers"))
      File.write(File.join(dir, "config/importmap.rb"), "pin \"application\"\n")
      controller_path = File.join(dir, "app/javascript/controllers/index.js")
      existing = <<~JAVASCRIPT
        import { eagerLoadControllersFrom } from '@hotwired/stimulus-loading'
        eagerLoadControllersFrom('controllers/recording_studio_users', application)
      JAVASCRIPT
      File.write(controller_path, existing)

      build_generator(dir).add_javascript

      assert_equal existing, File.read(controller_path)
    end
  end

  def test_add_javascript_reuses_existing_aliased_import
    with_temp_app do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      FileUtils.mkdir_p(File.join(dir, "app/javascript/controllers"))
      File.write(File.join(dir, "config/importmap.rb"), "pin \"application\"\n")
      controller_path = File.join(dir, "app/javascript/controllers/index.js")
      File.write(
        controller_path,
        "import { eagerLoadControllersFrom as eagerLoadRecordingStudioUsersControllersFrom } " \
        "from \"@hotwired/stimulus-loading\"\n"
      )

      build_generator(dir).add_javascript

      controllers = File.read(controller_path)
      assert_equal 1, controllers.scan("eagerLoadControllersFrom as eagerLoadRecordingStudioUsersControllersFrom").size
      assert_equal 1, controllers.scan(
        'eagerLoadRecordingStudioUsersControllersFrom("controllers/recording_studio_users", application)'
      ).size
    end
  end

  def test_install_guide_includes_migration_and_host_setup_steps
    install_guide = File.read(INSTALL_TEMPLATE_PATH)

    assert_includes install_guide, "bin/rails db:migrate"
    assert_includes install_guide, "Current.actor"
    assert_includes install_guide, "recording_studio_users:backfill_profiles"
    assert_includes install_guide, "config/importmap.rb"
    assert_includes install_guide, "app/javascript/controllers/index.js"
  end

  private

  def assert_tailwind_sources_present(css)
    tailwind_source_lines.each do |line|
      assert_includes css, line
    end
  end

  def assert_tailwind_sources_count(css, count)
    tailwind_source_lines.each do |line|
      assert_equal count, css.scan(line).size
    end
  end

  def tailwind_source_lines
    [
      '@source "../../vendor/bundle/**/recording_studio_users/app/views/**/*.erb";',
      '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/recording_studio_users-*/app/views/**/*.erb";',
      '@source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";',
      '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";'
    ]
  end
end
