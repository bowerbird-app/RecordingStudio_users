# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    class ConfirmationsController < Devise::ConfirmationsController
      include RecordingStudioUser::AuthRoutesHelper

      layout "recording_studio_user/auth"
    end
  end
end
