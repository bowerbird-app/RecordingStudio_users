# frozen_string_literal: true

require "rails/generators"

module RecordingStudioUser
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install RecordingStudioUser authentication, profiles, and admin reporting"

      class_option :profile_path,
                   type: :string,
                   default: "profile",
                   desc: "URL path for the singular profile resource"

      def copy_migrations
        invoke "recording_studio_user:migrations"
      end

      def copy_initializer
        destination = "config/initializers/recording_studio_user.rb"
        return say_status(:skip, destination, :yellow) if File.exist?(File.join(destination_root, destination))

        template "recording_studio_user_initializer.rb", destination
      end

      def install_routes
        routes_path = File.join(destination_root, "config/routes.rb")
        return unless File.exist?(routes_path)

        content = File.read(routes_path)
        return say_status(:skip, "RecordingStudioUser routes", :yellow) if content.include?(route_marker)

        sentinel = "Rails.application.routes.draw do\n"
        route_block = "\n#{route_marker}\n#{devise_route}\n#{profile_route}\n"
        inject_into_file "config/routes.rb", route_block, after: sentinel
      end

      def add_tailwind_sources
        tailwind_path = File.join(destination_root, "app/assets/tailwind/application.css")
        return say("Tailwind CSS not detected; skipped @source configuration.", :yellow) unless File.exist?(tailwind_path)

        content = File.read(tailwind_path)
        missing = tailwind_source_lines.reject { |line| content.include?(line) }
        return say("Tailwind sources already include RecordingStudioUser and FlatPack.", :green) if missing.empty?

        unless content.include?('@import "tailwindcss"')
          say("Add these Tailwind sources manually:", :yellow)
          missing.each { |line| say("  #{line}", :yellow) }
          return
        end

        inject_into_file "app/assets/tailwind/application.css",
                         "\n#{missing.join("\n")}\n",
                         after: "@import \"tailwindcss\";\n"
      end

      def show_next_steps
        readme "INSTALL.md" if behavior == :invoke
      end

      private

      def route_marker
        "  # RecordingStudioUser routes"
      end

      def devise_route
        <<~RUBY.chomp
          devise_for :users,
                     class_name: RecordingStudioUser.configuration.user_model,
                     controllers: {
                       sessions: "recording_studio_user/devise/sessions",
                       passwords: "recording_studio_user/devise/passwords"
                     }
        RUBY
      end

      def profile_route
        %(  resource :profile, path: RecordingStudioUser.configuration.profile_path, only: %i[show edit update], controller: "recording_studio_user/profiles")
      end

      def tailwind_source_lines
        [
          '@source "../../../vendor/bundle/**/recording_studio_user/app/views/**/*.erb";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/recording_studio_user-*/app/views/**/*.erb";',
          '@source "../../vendor/bundle/**/flat_pack/app/components/**/*.{rb,erb}";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flat_pack-*/app/components/**/*.{rb,erb}";'
        ]
      end
    end
  end
end
