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

      def copy_initializer
        unless File.exist?(
          Rails.root.join("config/initializers/recording_studio_user.rb")
        )
          copy_file "recording_studio_user_initializer.rb",
                    "config/initializers/recording_studio_user.rb"
        end
      end

      def add_tailwind_sources
        tailwind_path = Rails.root.join("app/assets/tailwind/application.css")
        unless tailwind_path.exist?
          return say "Tailwind CSS not detected. Add RecordingStudioUser sources manually if needed.",
                     :yellow
        end

        content = tailwind_path.read
        return say "Tailwind sources already include RecordingStudioUser.", :green if tailwind_sources.all? do |line|
          content.include?(line)
        end

        unless content.include?('@import "tailwindcss"')
          return say "Could not find @import \"tailwindcss\"; add RecordingStudioUser sources manually.",
                     :yellow
        end

        missing_sources = tailwind_sources.reject { |line| content.include?(line) }
        inject_into_file tailwind_path, after: "@import \"tailwindcss\";\n" do
          "\n/* Include RecordingStudioUser and FlatPack component sources */\n#{missing_sources.join("\n")}\n"
        end
      end

      def print_next_steps
        profile_path = "#{RecordingStudioUser.config.mount_path}/" \
                       "#{RecordingStudioUser.config.profile_route_path}"
        say "Profile: #{profile_path}", :green
        say "Users admin: #{RecordingStudioUser.config.mount_path}/#{RecordingStudioUser.config.admin_route_path}",
            :green
        say "Configure routes before they are drawn, then configure RecordingStudioAdmin access " \
            "and site-admin recording resolvers.",
            :yellow
        say "Enable section :users on the host-owned admin recordable and grant access with RecordingStudioAccessible.",
            :yellow
        say "The installer does not invoke recording_studio_user:admin. Host apps create the admin root, " \
            "resolvers, access items, and grants themselves.",
            :yellow
        say "RecordingStudioUser does not create User, Devise, migrations, admin roots, roles, or access grants.",
            :yellow
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
        sources = []

        begin
          engine_views = RecordingStudioUser::Engine.root.join("app/views")
          sources << %(@source "#{engine_views.relative_path_from(tailwind_dir)}/**/*.erb";) if engine_views.exist?
        rescue ArgumentError
          # Rails.root and the engine do not share a prefix; use the globs below.
        end

        begin
          components = Pathname.new(Gem::Specification.find_by_name("flat_pack").gem_dir).join("app/components")
          sources << %(@source "#{components.relative_path_from(tailwind_dir)}";) if components.exist?
        rescue Gem::MissingSpecError, ArgumentError
          # Fall back to the vendored /usr/local/bundle globs above.
        end

        sources
      end
    end
  end
end
