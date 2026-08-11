# frozen_string_literal: true

require "recording_studio_user/admin/users_screen"
require "recording_studio_user/admin/total_users_widget"
require "recording_studio_user/admin/users_section"

module RecordingStudioUser
  module Admin
    module_function

    def register!
      RecordingStudioAdmin.register_screen(UsersScreen)
      RecordingStudioAdmin.register_widget(TotalUsersWidget)
      RecordingStudioAdmin.register_section(UsersSection)
    end
  end
end
