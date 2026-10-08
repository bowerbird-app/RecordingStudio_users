# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Query
      DEFAULT_PER_PAGE = 50
      MAX_PER_PAGE = 100

      module_function

      def paginate(relation, page:, per_page:)
        normalized_page = normalize_page(page)
        normalized_per_page = normalize_per_page(per_page)
        total_count = relation.except(:limit, :offset).count
        {
          rows: page_rows(relation, normalized_page, normalized_per_page),
          meta: page_meta(normalized_page, normalized_per_page, total_count)
        }
      end

      def page_rows(relation, page, per_page)
        relation.offset((page - 1) * per_page).limit(per_page).to_a
      end

      def page_meta(page, per_page, total_count)
        {
          page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: [(total_count.to_f / per_page).ceil, 1].max
        }
      end

      def normalize_page(page)
        requested = page.to_i
        requested.positive? ? requested : 1
      end

      def normalize_per_page(per_page)
        requested = per_page.to_i
        requested = DEFAULT_PER_PAGE if requested <= 0
        [requested, MAX_PER_PAGE].min
      end
    end
  end
end
