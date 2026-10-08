# frozen_string_literal: true

module RecordingStudioUser
  module Api
    class UserCount
      def self.call(context = nil)
        Access.authorize_view!(context)
        { count: RecordingStudioUser.config.user_class.count }
      end
    end
  end
end
