# frozen_string_literal: true

# Dummy-only. Production Users does not load or depend on this gem.
RecordingStudioTermsAndConditions.configure do |config|
  config.app_name = "Studio"
end

Rails.application.config.to_prepare do
  users_views = RecordingStudioUser::Engine.root.join("app/views").to_s
  dummy_views = Rails.root.join("app/views").to_s
  ActionController::Base.prepend_view_path(users_views)
  ActionController::Base.prepend_view_path(dummy_views) unless ActionController::Base.view_paths.first.to_s == dummy_views

  helper = RecordingStudioTermsAndConditions::AgreeHelper
  unless helper.ancestors.include?(Dummy::TighterTermsAgree)
    helper.prepend Dummy::TighterTermsAgree
  end
end
