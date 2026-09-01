# frozen_string_literal: true

require "rails/generators"

module RecordingStudioNotificationsPush
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a Recording Studio push notification initializer"

      def copy_initializer
        template(
          "recording_studio_notifications_push.rb",
          "config/initializers/recording_studio_notifications_push.rb"
        )
      end
    end
  end
end
