# frozen_string_literal: true

require "rails/generators"

module RecordingStudioUsers
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioUsers engine into your application"

      class_option(
        :mount_path,
        type: :string,
        default: "/recording_studio_users",
        desc: "Route prefix used when mounting the engine"
      )
      class_option :user_class, type: :string, default: "User", desc: "Host Devise User class"

      def verify_dependencies
        missing = %w[
          RecordingStudio
          RecordingStudioAccessible
          RecordingStudioAttachable
          FlatPack
        ].reject { |name| name.safe_constantize }
        return if missing.empty?

        raise Thor::Error, "Missing required dependencies: #{missing.join(', ')}"
      end

      def install_devise
        generate "devise:install" unless File.exist?(destination_path("config/initializers/devise.rb"))
        model_path = destination_path("app/models/#{options[:user_class].underscore}.rb")
        generate "devise", options[:user_class] unless File.exist?(model_path)
      end

      def integrate_user
        invoke "recording_studio_users:integrate_user", [], user_class: options[:user_class]
      end

      def install_migrations
        invoke "recording_studio_users:migrations"
      end

      def mount_engine
        routes = destination_path("config/routes.rb")
        return if File.exist?(routes) && File.read(routes).include?("RecordingStudioUsers::Engine")

        route %(mount RecordingStudioUsers::Engine, at: "#{options[:mount_path]}")
        unless File.exist?(routes) && File.read(routes).include?("RecordingStudioAttachable::Engine")
          route %(mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable")
        end
      end

      def copy_initializer
        destination = "config/initializers/recording_studio_users.rb"
        return say("#{destination} already exists; leaving it unchanged.", :yellow) if File.exist?(destination_path(destination))

        template "recording_studio_users_initializer.rb", destination
      end

      def copy_devise_views
        Dir.glob(File.join(self.class.source_root, "devise/**/*.erb")).sort.each do |source|
          relative = source.delete_prefix("#{self.class.source_root}/")
          destination = File.join("app/views", relative)
          next if File.exist?(destination_path(destination))

          copy_file relative, destination
        end
      end

      def add_yaml_config
        return unless yes?("Would you like to add `config/recording_studio_users.yml` for environment-specific settings? [y/N]")

        template "recording_studio_users.yml", "config/recording_studio_users.yml"
      end

      def add_tailwind_source
        tailwind_css_path = Rails.root.join("app/assets/tailwind/application.css")
        return show_missing_tailwind_notice unless File.exist?(tailwind_css_path)

        tailwind_content = File.read(tailwind_css_path)
        missing_lines = missing_tailwind_source_lines(tailwind_content)

        if missing_lines.empty?
          say "Tailwind already configured to include RecordingStudioUsers and FlatPack sources.", :green
          return
        end

        if tailwind_content.include?('@import "tailwindcss"')
          inject_tailwind_sources(tailwind_css_path, missing_lines)
          return
        end

        show_manual_tailwind_notice(missing_lines)
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end

      private

      def destination_path(path)
        File.join(destination_root, path)
      end

      def show_missing_tailwind_notice
        say "Tailwind CSS not detected. Skipping Tailwind configuration.", :yellow
        say "If you use Tailwind, add these lines to your Tailwind CSS config:", :yellow
        tailwind_source_lines.each do |line|
          say "  #{line}", :yellow
        end
      end

      def missing_tailwind_source_lines(tailwind_content)
        tailwind_source_lines.reject { |line| tailwind_content.include?(line) }
      end

      def inject_tailwind_sources(tailwind_css_path, missing_lines)
        inject_into_file tailwind_css_path, after: "@import \"tailwindcss\";\n" do
          "#{formatted_tailwind_source_block(missing_lines)}\n"
        end
        say "Added RecordingStudioUsers and FlatPack sources to Tailwind CSS configuration.", :green
        say "Run 'bin/rails tailwindcss:build' to rebuild your CSS.", :green
      end

      def formatted_tailwind_source_block(missing_lines)
        [
          "\n/* Include RecordingStudioUsers engine views for Tailwind CSS */",
          missing_lines.first(2),
          "\n/* Include FlatPack component sources for Tailwind CSS */",
          missing_lines.drop(2)
        ].flatten.reject(&:empty?).join("\n")
      end

      def show_manual_tailwind_notice(missing_lines)
        say "Could not find @import \"tailwindcss\" in your Tailwind config.", :yellow
        say "Please manually add these lines to your Tailwind CSS config:", :yellow
        missing_lines.each do |line|
          say "  #{line}", :yellow
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
  end
end
