# frozen_string_literal: true

module RecordingStudioUsers
  module Services
    class SearchUsers
      def self.call(...)
        new(...).call
      end

      def initialize(query:, actor:, scope: nil, root_recording: nil, limit: nil, exclude_ids: [], context: nil)
        @query = query.to_s.squish
        @actor = actor
        @requested_scope = scope
        @root_recording = root_recording
        @limit = limit
        @exclude_ids = Array(exclude_ids).compact_blank.first(100)
        @context = context
      end

      def call
        return Result.failure("Authentication is required") unless actor&.persisted?
        return Result.failure("Search query is too short") if query.length < 2
        return Result.failure("User search is not authorized") unless authorized?

        users = search_relation.limit(effective_limit).to_a
        RecordingStudioUsers.preload_user_information(users, context:)
        visible = users.select { |user| RecordingStudioUsers.identity_visible?(user, actor:, context:) }
        Result.success(visible)
      rescue ActiveRecord::StatementInvalid, ArgumentError => e
        Result.failure(e)
      end

      private

      attr_reader :query, :actor, :requested_scope, :root_recording, :limit, :exclude_ids, :context

      def authorized?
        return false unless RecordingStudioUsers.call_configured(
          RecordingStudioUsers.configuration.search_authorizer,
          actor:,
          root_recording:,
          context:
        )
        return true unless root_recording

        RecordingStudioAccessible.authorized?(actor:, recording: root_recording, role: :view)
      end

      def search_relation
        relation = requested_scope || configured_scope
        raise ArgumentError, "Configured search scope must be an Active Record relation" unless relation.respond_to?(:where)
        unless relation.klass.base_class == RecordingStudioUsers.user_class.base_class
          raise ArgumentError, "Configured search scope must select the configured User class"
        end

        table = relation.klass.arel_table
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
        searchable = Arel::Nodes::NamedFunction.new("LOWER", [table[:email]]).matches(pattern)
        relation.where(searchable).where.not(id: exclude_ids).reorder(:email, :id)
      end

      def configured_scope
        scope = RecordingStudioUsers.call_configured(
          RecordingStudioUsers.configuration.search_scope,
          actor:,
          root_recording:,
          context:
        )
        scope || RecordingStudioUsers.user_class.none
      end

      def effective_limit
        requested = limit.present? ? Integer(limit) : RecordingStudioUsers.configuration.picker_limit
        [requested, RecordingStudioUsers.configuration.picker_limit].min.clamp(1, 100)
      end
    end
  end
end
