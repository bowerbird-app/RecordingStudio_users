# frozen_string_literal: true

module RecordingStudioUser
  module Devise
    class SessionsController < ::Devise::SessionsController
      layout -> { RecordingStudioUser.configuration.default_layout }
    end
  end
end
