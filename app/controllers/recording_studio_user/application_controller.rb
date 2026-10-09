# frozen_string_literal: true

module RecordingStudioUser
  class ApplicationController < ActionController::Base
    # Other gems (TnC) may prepend their view paths onto ActionController::Base.
    # Prefer the host app/views first on every Users controller, matching normal
    # Rails engine override behaviour.
    if defined?(Rails.application) && Rails.application.respond_to?(:root)
      prepend_view_path Rails.application.root.join("app/views")
    end

    protect_from_forgery with: :exception
    layout -> { RecordingStudioUser.config.layout }
    helper RecordingStudio::LayoutHelper
    helper RecordingStudioUser::AuthRoutesHelper
    helper RecordingStudioUser::OmniauthHelper
    include Rails.application.routes.mounted_helpers

    helper Rails.application.routes.mounted_helpers
  end
end
