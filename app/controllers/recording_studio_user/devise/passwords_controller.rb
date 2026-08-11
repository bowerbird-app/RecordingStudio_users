# frozen_string_literal: true

module RecordingStudioUser
  module Devise
    class PasswordsController < ::Devise::PasswordsController
      layout -> { RecordingStudioUser.configuration.default_layout }
    end
  end
end
