# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioUser
  module Generators
    class MigrationsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Copies RecordingStudioUser People, Profile, and Identity tables into the host application."

      class_option :skip_existing,
                   type: :boolean,
                   default: true,
                   desc: "Do not create a second copy of an engine migration"

      def copy_people_and_profiles_migration
        if options[:skip_existing] && people_profiles_migration_exists?
          say "skip create_recording_studio_user_people_and_profiles.rb (already exists)", :yellow
        else
          migration_template "create_recording_studio_user_people_and_profiles.rb.tt",
                             "db/migrate/create_recording_studio_user_people_and_profiles.rb"
        end
      end

      def copy_identities_migration
        if options[:skip_existing] && identities_migration_exists?
          say "skip create_recording_studio_user_identities.rb (already exists)", :yellow
        else
          migration_template "create_recording_studio_user_identities.rb.tt",
                             "db/migrate/create_recording_studio_user_identities.rb"
        end
      end

      private

      def people_profiles_migration_exists?
        Dir.glob(
          File.join(destination_root, "db/migrate", "*_create_recording_studio_user_people_and_profiles.rb")
        ).any?
      end

      def identities_migration_exists?
        Dir.glob(
          File.join(destination_root, "db/migrate", "*_create_recording_studio_user_identities.rb")
        ).any?
      end
    end
  end
end
