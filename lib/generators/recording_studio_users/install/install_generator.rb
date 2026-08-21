# frozen_string_literal: true

require "rails/generators"

module RecordingStudioUsers
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioUsers engine into your application"

      GENERATED_SOURCES_PATH = "app/assets/tailwind/recording_studio_users_sources.css"

      class_option(
        :mount_path,
        type: :string,
        default: "/recording_studio_users",
        desc: "Route prefix used when mounting the engine"
      )
      class_option :skip_devise, type: :boolean, default: false,
                                 desc: "Skip Devise installation and User generation"
      class_option :skip_migrations, type: :boolean, default: false,
                                     desc: "Skip copying Users migrations"

      def install_devise_user
        return if options[:skip_devise]

        generate "devise:install" unless File.exist?(File.join(destination_root, "config/initializers/devise.rb"))
        generate "devise", "User" unless File.exist?(File.join(destination_root, "app/models/user.rb"))
      end

      def mount_engine
        route %(mount RecordingStudioUsers::Engine, at: "#{options[:mount_path]}")
      end

      def copy_initializer
        template "recording_studio_users_initializer.rb", "config/initializers/recording_studio_users.rb"
      end

      def wire_application_controller
        application_controller = File.join(destination_root, "app/controllers/application_controller.rb")
        return unless File.exist?(application_controller)

        inject_into_class application_controller, "ApplicationController", <<~RUBY
          include RecordingStudio::RootSwitchable::ControllerSupport
          include RecordingStudioUsers::CurrentContext
        RUBY
      end

      def copy_migrations
        return if options[:skip_migrations]

        generate "recording_studio_users:migrations"
      end

      def add_tailwind_source
        tailwind_css_path = File.join(destination_root, "app/assets/tailwind/application.css")
        return show_missing_tailwind_notice unless File.exist?(tailwind_css_path)

        copy_file "recording_studio_users_tailwind.rake", "lib/tasks/recording_studio_users_tailwind.rake"
        ignore_generated_sources
        tailwind_content = File.read(tailwind_css_path)

        if tailwind_content.include?(tailwind_import_line)
          say "Tailwind already imports the RecordingStudioUsers source list.", :green
          return
        end

        return show_manual_tailwind_notice unless tailwind_content.include?('@import "tailwindcss"')

        inject_tailwind_sources(tailwind_css_path)
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end

      private

      def ignore_generated_sources
        return unless File.exist?(File.join(destination_root, ".gitignore"))

        append_to_file ".gitignore", "\n#{GENERATED_SOURCES_PATH}\n"
      end

      def show_missing_tailwind_notice
        say "Tailwind CSS not detected. Skipping Tailwind configuration.", :yellow
        say "If you use Tailwind, add this line to your Tailwind CSS config:", :yellow
        say "  #{tailwind_import_line}", :yellow
      end

      def inject_tailwind_sources(tailwind_css_path)
        inject_into_file tailwind_css_path, after: "@import \"tailwindcss\";\n" do
          "\n/* Gem-provided views and components, written by " \
            "rails tailwindcss:recording_studio_users_sources */\n" \
            "#{tailwind_import_line}\n"
        end
        say "Tailwind now imports the RecordingStudioUsers source list.", :green
        say "Run 'bin/rails tailwindcss:build' to rebuild your CSS.", :green
      end

      def show_manual_tailwind_notice
        say "Could not find @import \"tailwindcss\" in your Tailwind config.", :yellow
        say "Please manually add this line to your Tailwind CSS config:", :yellow
        say "  #{tailwind_import_line}", :yellow
      end

      def tailwind_import_line
        '@import "./recording_studio_users_sources.css";'
      end
    end
  end
end
