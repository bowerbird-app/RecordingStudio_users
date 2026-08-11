# frozen_string_literal: true

require "rails/generators"

module RecordingStudioUser
  module Generators
    class AdminGenerator < Rails::Generators::Base
      desc "Explain how to enable RecordingStudioUser definitions on a host admin recordable"

      def register_definitions
        initializer = File.join(destination_root, "config/initializers/recording_studio_user.rb")
        unless File.exist?(initializer)
          say "Run `bin/rails generate recording_studio_user:install` first.", :yellow
          return
        end

        say "RecordingStudioUser admin definitions are registered by its initializer.", :green
        say "Add `section :users` to your chosen recordable's recording_studio_admin_sections block."
        say "Admin root creation, route mounting, and RecordingStudioAccessible grants remain host-owned."
      end
    end
  end
end
