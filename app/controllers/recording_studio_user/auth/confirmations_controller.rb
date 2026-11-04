# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class ConfirmationsController < Devise::ConfirmationsController
      include Rails.application.routes.mounted_helpers
      include RecordingStudio::ControllerLayout
      include RecordingStudioUser::AuthRoutesHelper

      recording_studio_layout { RecordingStudioUser.configuration.layout }
    end
  end
end
