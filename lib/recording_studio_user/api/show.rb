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
        Serialize.user(Users.find!(context))
      end

      private

      attr_reader :context
    end
  end
end
