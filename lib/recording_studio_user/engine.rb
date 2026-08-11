# frozen_string_literal: true

module RecordingStudioUser
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioUser

    config.to_prepare do
      RecordingStudioUser.configuration.register_admin!
    end
  end
end
