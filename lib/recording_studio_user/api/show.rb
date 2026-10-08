# frozen_string_literal: true

module RecordingStudioUser
  module Api
    class Show
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        Access.authorize_view!(context)
        Serialize.user(find_user!)
      end

      private

      attr_reader :context

      def find_user!
        user = RecordingStudioUser.config.user_class.find_by(id: Params.record_id(context))
        Errors.not_found! if user.blank?

        user
      end
    end
  end
end
