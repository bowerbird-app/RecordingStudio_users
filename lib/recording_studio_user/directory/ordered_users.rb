# frozen_string_literal: true

module RecordingStudioUser
  module Directory
    module_function

    def ordered_users
      RecordingStudioUser.config.user_class.order(created_at: :desc)
    end
  end
end
