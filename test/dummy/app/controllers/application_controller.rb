class ApplicationController < ActionController::Base
  include RecordingStudio::RootSwitchable::ControllerSupport
  include RecordingStudioUsers::CurrentContext

  skip_recording_studio_root_resolution if: :devise_controller?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  layout :application_layout

  before_action :authenticate_user!

  private

  def application_layout
    devise_controller? ? "application" : "flat_pack_sidebar"
  end

end
