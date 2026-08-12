# frozen_string_literal: true

module RecordingStudioUser
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout -> { RecordingStudioUser.config.layout }
  end
end
