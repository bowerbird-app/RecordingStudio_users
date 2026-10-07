# frozen_string_literal: true

module RecordingStudioUser
  module Api
    class UserCount
      def self.call(_context = nil)
        { count: RecordingStudioUser.config.user_class.count }
      end
    end
  end
end
