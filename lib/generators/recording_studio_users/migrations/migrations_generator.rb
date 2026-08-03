# frozen_string_literal: true

require "rails/generators"

module RecordingStudioUsers
  module Generators
    class MigrationsGenerator < Rails::Generators::Base
      desc "Copies RecordingStudioUsers migrations into the host application"

      def copy_migrations
        rails_command "recording_studio_users:install:migrations"
      end
    end
  end
end
