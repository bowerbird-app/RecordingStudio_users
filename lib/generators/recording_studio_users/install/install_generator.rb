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
        ].reject(&:safe_constantize)
        return if missing.empty?

        raise Thor::Error, "Missing required dependencies: #{missing.join(', ')}"
      end

      def install_attachable
        invoke "recording_studio_attachable:install"
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
        content = File.exist?(routes) ? File.read(routes) : ""

        unless content.include?("RecordingStudioUsers::Engine")
          route %(mount RecordingStudioUsers::Engine, at: "#{options[:mount_path]}", as: :recording_studio_users)
        end
        return if content.include?("RecordingStudioAttachable::Engine")

        route "mount RecordingStudioAttachable::Engine, at: \"/recording_studio_attachable\", " \
              "as: :recording_studio_attachable"
      end

      def copy_initializer
        destination = "config/initializers/recording_studio_users.rb"
        if File.exist?(destination_path(destination))
          return say("#{destination} already exists; leaving it unchanged.",
                     :yellow)
        end

        template "recording_studio_users_initializer.rb", destination
      end

      def copy_devise_views
        Dir.glob(File.join(self.class.source_root, "devise/**/*.erb")).each do |source|
          relative = source.delete_prefix("#{self.class.source_root}/")
          destination = File.join("app/views", relative)
          next if File.exist?(destination_path(destination))

          copy_file relative, destination
        end
      end

      def add_yaml_config
        question = "Would you like to add `config/recording_studio_users.yml` " \
                   "for environment-specific settings? [y/N]"
        return unless yes?(question)

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

      def add_javascript
        add_importmap_pins
        add_stimulus_loader
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end

      private

      def add_importmap_pins
        path = destination_path("config/importmap.rb")
        return show_missing_javascript_notice("config/importmap.rb", importmap_pin_block) unless File.exist?(path)
        return if File.read(path).include?("controllers/recording_studio_users")

        append_to_file path, "\n#{importmap_pin_block}\n"
      end

      def add_stimulus_loader
        path = destination_path("app/javascript/controllers/index.js")
        return show_missing_javascript_notice("app/javascript/controllers/index.js", stimulus_loader_block) unless File.exist?(path)
        content = File.read(path)
        return if content.match?(recording_studio_users_loader_pattern)

        block = content.match?(recording_studio_users_import_pattern) ? stimulus_loader_call : stimulus_loader_block
        append_to_file path, "\n#{block}\n"
      end

      def importmap_pin_block
        <<~RUBY.chomp
          pin_all_from RecordingStudioUsers::Engine.root.join("app/javascript/controllers/recording_studio_users"),
            under: "controllers/recording_studio_users",
            to: "controllers/recording_studio_users"
        RUBY
      end

      def stimulus_loader_block
        <<~JAVASCRIPT.chomp
          import { eagerLoadControllersFrom as eagerLoadRecordingStudioUsersControllersFrom } from "@hotwired/stimulus-loading"
          #{stimulus_loader_call}
        JAVASCRIPT
      end

      def stimulus_loader_call
        'eagerLoadRecordingStudioUsersControllersFrom("controllers/recording_studio_users", application)'
      end

      def recording_studio_users_loader_pattern
        /^\s*(?:eagerLoadControllersFrom|eagerLoadRecordingStudioUsersControllersFrom)\(\s*["']controllers\/recording_studio_users["']/
      end

      def recording_studio_users_import_pattern
        /^\s*import\s+\{[^}]*\beagerLoadControllersFrom\s+as\s+eagerLoadRecordingStudioUsersControllersFrom\b/
      end

      def show_missing_javascript_notice(path, content)
        say "#{path} was not found. Add this RecordingStudioUsers JavaScript configuration manually:", :yellow
        content.each_line { |line| say "  #{line.chomp}", :yellow }
      end

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
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/' \
          'recording_studio_users-*/app/views/**/*.erb";',
          '@source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/' \
          'flatpack-*/app/components/**/*.{rb,erb}";'
        ]
      end
    end
  end
end
