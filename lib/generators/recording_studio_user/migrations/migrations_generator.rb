# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioUser
  module Generators
    class MigrationsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Copies RecordingStudioUser migrations into the host application."

      class_option :skip_existing,
                   type: :boolean,
                   default: true,
                   desc: "Do not create a second copy of an engine migration"

      MIGRATIONS = {
        "create_recording_studio_user_people_and_profiles" => "create_recording_studio_user_people_and_profiles.rb.tt",
        "add_authentication_method_to_users" => "add_authentication_method_to_users.rb.tt",
        "add_devise_confirmable_to_users" => "add_devise_confirmable_to_users.rb.tt",
        "create_recording_studio_user_otp_challenges" => "create_recording_studio_user_otp_challenges.rb.tt"
      }.freeze

      def copy_migrations
        MIGRATIONS.each do |basename, template|
          if options[:skip_existing] && migration_already_exists?(basename)
            say "skip #{basename}.rb (already exists)", :yellow
            next
          end

          migration_template template, "db/migrate/#{basename}.rb"
        end
      end

      private

      def migration_already_exists?(basename)
        Dir.glob(File.join(destination_root, "db/migrate", "*_#{basename}.rb")).any?
      end
    end
  end
end
