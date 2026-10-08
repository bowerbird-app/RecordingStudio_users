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
          filtered_users,
          limit: Params.pagination_limit(context),
          pagination_token: Params.pagination_token(context)
        )
        term = Params.search_term(context).strip
        meta = page.fetch(:meta)
        meta = meta.merge(q: term) if term.present?
        Serialize.collection(page.fetch(:rows), meta: meta)
      end

      private

      attr_reader :context

      def filtered_users
        Query.apply_search(user_class.all, Params.search_term(context))
      end

      def user_class
        RecordingStudioUser.config.user_class
      end
    end
  end
end
