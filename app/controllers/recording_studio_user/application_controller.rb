# frozen_string_literal: true

module RecordingStudioUser
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout -> { RecordingStudioUser.config.layout }
    helper RecordingStudio::LayoutHelper
    helper_method :recording_studio_attachable

    private

    def recording_studio_attachable
      main_app.recording_studio_attachable
    end
  end
end
