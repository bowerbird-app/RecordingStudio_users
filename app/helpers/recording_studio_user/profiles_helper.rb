# frozen_string_literal: true

module RecordingStudioUser
  module ProfilesHelper
    def profile_display_name(user)
      RecordingStudioUser.display_name_for(user)
    end

    def recording_access_management_path(recording)
      recording_studio_accessible_routes.recording_accesses_path(recording)
    end

    def recording_access_management_link(recording, label: "Manage access", **)
      link_to(label, recording_access_management_path(recording), **)
    end

    private

    def recording_studio_accessible_routes
      return recording_studio_accessible if respond_to?(:recording_studio_accessible)

      main_app.recording_studio_accessible
    end
  end
end
