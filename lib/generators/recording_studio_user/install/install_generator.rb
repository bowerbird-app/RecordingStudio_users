# frozen_string_literal: true

require "pathname"
require "rails/generators"

module RecordingStudioUser
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioUser into your application"

      def mount_engine
        routes_path = Rails.root.join("config/routes.rb")
        mount = "mount RecordingStudioUser::Engine => " \
                "RecordingStudioUser.config.mount_path, as: :recording_studio_users"
        return say "RecordingStudioUser is already mounted.", :green if routes_path.read.include?(mount)

        inject_into_file routes_path, before: /^end\s*\z/ do
          "\n  #{mount}\n"
        end
      end

      def mount_auth_routes
        routes_path = Rails.root.join("config/routes.rb")
        content = routes_path.read
        if content.include?("recording_studio_user_auth_for")
          return say "Users auth routes are already mounted.",
                     :green
        end

        unless content.match?(/\bdevise_for\s+:users\b/)
          return say "No devise_for :users found. Add recording_studio_user_auth_for :users after " \
                     "skipping Devise sessions/registrations/passwords.", :yellow
        end

        inject_into_file routes_path, after: /devise_for\s+:users[^\n]*\n(?:[ \t]+[^\n]+\n)*/ do
          "\n  recording_studio_user_auth_for :users\n"
        end
        say "Added recording_studio_user_auth_for :users. Skip Devise sessions, registrations, and " \
            "passwords on devise_for so the gem owns those screens.", :yellow
      end

      def copy_initializer
        return if File.exist?(Rails.root.join("config/initializers/recording_studio_user.rb"))

        copy_file "recording_studio_user_initializer.rb", "config/initializers/recording_studio_user.rb"
      end

      def add_tailwind_sources
        tailwind_path = Rails.root.join("app/assets/tailwind/application.css")
        unless tailwind_path.exist?
          return say "Tailwind CSS not detected. Add RecordingStudioUser sources manually if needed.",
                     :yellow
        end

        content = tailwind_path.read
        return say "Tailwind sources already include RecordingStudioUser.", :green if
          tailwind_sources.all? { |line| content.include?(line) }

        unless content.include?('@import "tailwindcss"')
          return say "Could not find @import \"tailwindcss\"; add RecordingStudioUser sources manually.",
                     :yellow
        end

        missing = tailwind_sources.reject { |line| content.include?(line) }
        inject_into_file tailwind_path, after: "@import \"tailwindcss\";\n" do
          "\n/* Include RecordingStudioUser and FlatPack component sources */\n#{missing.join("\n")}\n"
        end
      end

      def print_next_steps
        cfg = RecordingStudioUser.config
        say "Profile: #{cfg.mount_path}/#{cfg.profile_route_path}", :green
        say "Users admin: #{cfg.mount_path}/#{cfg.admin_route_path}", :green
        say "Configure routes before they are drawn, then RecordingStudioAdmin access and resolvers.",
            :yellow
        say "Enable section :users on the host admin root. First staff: bootstrap_owner_access!; " \
            "later: grant_access. Hosts create the admin root themselves.", :yellow
        say "People + Profile + Identity: bin/rails generate recording_studio_user:migrations", :green
        say "Register People and Profile in recordable_types, then db:migrate. Accessible and " \
            "Attachable on Profile only. create_user! / record_profile! use bootstrap_owner_access!.",
            :yellow
        say "OmniAuth credentials under omniauth:; callbacks at recording_studio_user/omniauth_callbacks. " \
            "Skip sessions/registrations/passwords, then recording_studio_user_auth_for :users for gem " \
            "login chrome (OTP when otp_enabled).", :yellow
        say "Uploads: recording_studio_attachable:install, migrations, and Active Storage.", :yellow
      end

      private

      def tailwind_sources
        [
          *resolved_tailwind_sources,
          '@source "../../vendor/bundle/**/recording_studio_user/app/views/**/*.erb";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/' \
          'recording_studio_user-*/app/views/**/*.erb";',
          '@source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";',
          '@source "../../../../../../usr/local/bundle/ruby/**/bundler/gems/flatpack-*/app/components/**/*.{rb,erb}";'
        ].uniq
      end

      def resolved_tailwind_sources
        return [] unless defined?(Rails) && Rails.respond_to?(:root) && Rails.root

        tailwind_dir = Rails.root.join("app/assets/tailwind")
        [
          relative_source(RecordingStudioUser::Engine.root.join("app/views"), tailwind_dir, "/**/*.erb"),
          relative_source(flat_pack_components_path, tailwind_dir)
        ].compact
      end

      def flat_pack_components_path
        Pathname.new(Gem::Specification.find_by_name("flat_pack").gem_dir).join("app/components")
      rescue Gem::MissingSpecError
        nil
      end

      def relative_source(path, from_dir, glob = "")
        return unless path&.exist?

        %(@source "#{path.relative_path_from(from_dir)}#{glob}";)
      rescue ArgumentError
        nil
      end
    end
  end
end
