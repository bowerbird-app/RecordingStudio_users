# frozen_string_literal: true

module RecordingStudioUser
  module ProfilesHelper
    def profile_display_name(user)
      RecordingStudioUser.display_name_for(user)
    end
  end
end
