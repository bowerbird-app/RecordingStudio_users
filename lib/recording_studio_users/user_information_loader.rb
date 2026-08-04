# frozen_string_literal: true

module RecordingStudioUsers
  class UserInformationLoader
    CACHE_KEY = :recording_studio_users_information_cache
    Information = Data.define(
      :user,
      :user_root,
      :root_recording,
      :profile_recording,
      :profile,
      :avatar_recording,
      :attachment,
      :valid
    )

    class << self
      def cached(user, context: nil)
        cache = ActiveSupport::IsolatedExecutionState[CACHE_KEY]
        cache&.dig(context_key(context), record_key(user))
      end

      private

      def context_key(context) = context ? context.object_id : :default
      def record_key(user) = [user.class.base_class.name, user.id.to_s]
    end

    def initialize(users, include:, context:)
      @input = users
      @users = Array(users.respond_to?(:to_ary) ? users.to_ary : users.to_a)
      @includes = Array(include).map(&:to_sym)
      @context = context
      validate_includes!
    end

    def call
      load_information
      input.respond_to?(:to_ary) ? users : input
    end

    private

    attr_reader :input, :users, :includes, :context

    def validate_includes!
      unknown = includes - %i[profile avatar]
      raise ArgumentError, "Unknown preload includes: #{unknown.join(', ')}" if unknown.any?
    end

    def load_information
      return if users.empty?

      roots = load_roots
      root_recordings = load_root_recordings(roots)
      profile_recordings = includes.intersect?(%i[profile avatar]) ? load_profiles(root_recordings) : {}
      avatar_recordings = includes.include?(:avatar) ? load_avatars(profile_recordings) : {}
      store(users, roots, root_recordings, profile_recordings, avatar_recordings)
    end

    def load_roots
      users.group_by { |user| user.class.base_class.name }.each_with_object({}) do |(type, typed_users), result|
        UserRoot.where(user_type: type, user_id: typed_users.map(&:id)).find_each do |root|
          result[[root.user_type, root.user_id.to_s]] = root
        end
      end
    end

    def load_root_recordings(roots)
      keyed_recordings(
        RecordingStudio::Recording.unscoped.where(
          recordable_type: "RecordingStudioUsers::UserRoot",
          recordable_id: roots.values.map(&:id),
          parent_recording_id: nil
        ).preload(:recordable),
        &:recordable_id
      )
    end

    def load_profiles(root_recordings)
      keyed_recordings(
        RecordingStudio::Recording.unscoped.where(
          parent_recording_id: root_recordings.values.map(&:id),
          recordable_type: "RecordingStudioUsers::Profile",
          trashed_at: nil
        ).preload(:recordable),
        &:parent_recording_id
      )
    end

    def load_avatars(profile_recordings)
      keyed_recordings(
        RecordingStudio::Recording.unscoped.where(
          parent_recording_id: profile_recordings.values.map(&:id),
          recordable_type: "RecordingStudioAttachable::Attachment",
          trashed_at: nil
        ).preload(recordable: {file_attachment: :blob}),
        &:parent_recording_id
      )
    end

    def keyed_recordings(scope)
      scope.each_with_object({}) do |recording, result|
        key = yield(recording).to_s
        result[key] = result.key?(key) ? :duplicate : recording
      end
    end

    def store(ordered_users, roots, root_recordings, profile_recordings, avatar_recordings)
      cache = ActiveSupport::IsolatedExecutionState[CACHE_KEY] ||= {}
      context_cache = cache[self.class.send(:context_key, context)] ||= {}

      ordered_users.each do |user|
        root = roots[[user.class.base_class.name, user.id.to_s]]
        root_recording = root && root_recordings[root.id.to_s]
        profile_recording = valid_recording(root_recording) && profile_recordings[root_recording.id.to_s]
        avatar_recording = valid_recording(profile_recording) && avatar_recordings[profile_recording.id.to_s]
        valid = [root_recording, profile_recording, avatar_recording].none? { |value| value == :duplicate }
        profile_recording = nil unless valid_recording(profile_recording)
        avatar_recording = nil unless valid_recording(avatar_recording)

        context_cache[self.class.send(:record_key, user)] = Information.new(
          user:,
          user_root: root,
          root_recording: valid_recording(root_recording) ? root_recording : nil,
          profile_recording:,
          profile: profile_recording&.recordable,
          avatar_recording:,
          attachment: avatar_recording&.recordable,
          valid:
        )
      end
    end

    def valid_recording(recording) = recording.present? && recording != :duplicate
  end
end
