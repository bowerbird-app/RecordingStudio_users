class HomeController < ApplicationController
  # Dummy debug chrome: sidebar + docs links. Product surfaces keep
  # recording_studio/default_layout via ApplicationController.
  layout "flat_pack_sidebar"

  def index
  end
end
