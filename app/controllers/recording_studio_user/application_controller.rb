# frozen_string_literal: true

module RecordingStudioUser
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout -> { RecordingStudioUser.config.layout }
    helper RecordingStudio::LayoutHelper
    helper RecordingStudioUser::AuthRoutesHelper
    include Rails.application.routes.mounted_helpers

    helper Rails.application.routes.mounted_helpers
  end
end
