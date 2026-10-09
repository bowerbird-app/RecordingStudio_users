# frozen_string_literal: true

module RecordingStudioUser
  module Api
    class Index
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        Access.authorize_view!(context)
        page = Query.paginate(
          RecordingStudioUser.config.user_class.order(created_at: :desc),
          page: Params.page(context),
          per_page: Params.per_page(context)
        )
        Serialize.collection(page.fetch(:rows), meta: page.fetch(:meta))
      end

      private

      attr_reader :context
    end
  end
end
