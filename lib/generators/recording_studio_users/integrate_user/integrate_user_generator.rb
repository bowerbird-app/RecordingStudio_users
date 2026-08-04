# frozen_string_literal: true

require "rails/generators"

module RecordingStudioUsers
  module Generators
    class IntegrateUserGenerator < Rails::Generators::Base
      class_option :user_class, type: :string, default: "User", desc: "Host User class"

      def include_concern
        path = "app/models/#{options[:user_class].underscore}.rb"
        absolute_path = File.join(destination_root, path)
        unless File.exist?(absolute_path)
          say "Could not find #{path}. Add `include RecordingStudioUsers::User` manually.", :yellow
          return
        end

        content = File.read(absolute_path)
        return say("#{options[:user_class]} already includes RecordingStudioUsers::User.", :green) if
          content.include?("include RecordingStudioUsers::User")

        class_line = "class #{options[:user_class]} < ApplicationRecord"
        unless content.include?(class_line)
          say "Could not safely edit #{path}. Add `include RecordingStudioUsers::User` inside the class.", :yellow
          return
        end

        inject_into_file path, "\n  include RecordingStudioUsers::User", after: class_line
      end
    end
  end
end
