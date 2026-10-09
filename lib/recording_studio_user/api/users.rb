# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Users
      module_function

      def find!(context)
        user = RecordingStudioUser.config.user_class.find_by(id: Params.record_id(context))
        Errors.not_found! if user.blank?

        user
      end
    end
  end
end
