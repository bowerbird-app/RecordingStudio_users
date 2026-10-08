# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Query
      DEFAULT_LIMIT = 50
      MAX_LIMIT = 100
      TOKEN_PURPOSE = "recording_studio_user.api.users.pagination"

      module_function

      def apply_search(relation, term)
        needle = term.to_s.strip
        return relation if needle.blank?

        pattern = "%#{escape_like(needle.downcase)}%"
        profile_ids = Profile.where(
          "LOWER(first_name) LIKE :q OR LOWER(COALESCE(last_name, '')) LIKE :q",
          q: pattern
        ).select(:user_id)
        relation.where("LOWER(email) LIKE :q OR id IN (:profile_user_ids)", q: pattern, profile_user_ids: profile_ids)
      end

      def paginate(relation, limit:, pagination_token:)
        normalized_limit = normalize_limit(limit)
        paged = relation.reorder(created_at: :desc, id: :desc)
        payload = decode_token(pagination_token)
        paged = apply_cursor(paged, payload) if payload
        rows = paged.limit(normalized_limit + 1).to_a
        has_more = rows.length > normalized_limit
        items = has_more ? rows.first(normalized_limit) : rows
        {
          rows: items,
          meta: {
            limit: normalized_limit,
            has_more: has_more,
            next_pagination_token: next_token(items, has_more)
          }
        }
      end

      def normalize_limit(limit)
        requested = limit.to_i
        requested = DEFAULT_LIMIT if requested <= 0
        [requested, MAX_LIMIT].min
      end

      def apply_cursor(relation, payload)
        created_at = Time.iso8601(payload.fetch("created_at"))
        id = payload.fetch("id")
        table = relation.klass.arel_table
        relation.where(
          table[:created_at].lt(created_at)
            .or(table[:created_at].eq(created_at).and(table[:id].lt(id)))
        )
      end

      def next_token(items, has_more)
        return unless has_more

        last = items.last
        encode_token("created_at" => last.created_at.utc.iso8601(6), "id" => last.id)
      end

      def encode_token(payload)
        verifier.generate(payload, purpose: TOKEN_PURPOSE)
      end

      def decode_token(token)
        return if token.blank?

        payload = verifier.verify(token.to_s, purpose: TOKEN_PURPOSE)
        raise invalid_pagination_error, "Invalid pagination token" unless payload.is_a?(Hash)

        payload
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError, TypeError
        raise invalid_pagination_error, "Invalid pagination token"
      end

      def verifier
        Rails.application.message_verifier(TOKEN_PURPOSE)
      end

      def escape_like(value)
        value.gsub(/[%_\\]/) { |char| "\\#{char}" }
      end

      def invalid_pagination_error
        if defined?(RecordingStudioApi::InvalidPaginationTokenError)
          RecordingStudioApi::InvalidPaginationTokenError
        else
          ArgumentError
        end
      end
    end
  end
end
