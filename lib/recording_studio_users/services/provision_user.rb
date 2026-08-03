# frozen_string_literal: true

module RecordingStudioUsers
  module Services
    class ProvisionUser < BaseService
      def initialize(user:, actor:)
        @user = user
        @actor = actor
      end

      private

      def service_args
        { user_id: @user&.id, actor_id: @actor&.id }
      end

      def perform
        return failure("User must be persisted") unless @user&.persisted?
        return failure("Actor must be persisted") unless @actor&.persisted?

        ActiveRecord::Base.transaction do
          user_root = find_or_create_user_root!
          root_recording = RecordingStudio.root_recording_for(user_root)
          ensure_initial_admin_access!(root_recording)
          profile_recording = find_or_create_profile_recording!(root_recording)

          success(
            user_root: user_root,
            root_recording: root_recording,
            profile_recording: profile_recording,
            profile: profile_recording.recordable
          )
        end
      rescue StandardError => e
        failure(e)
      end

      def find_or_create_user_root!
        RecordingStudioUsers::UserRoot.find_or_create_by!(user: @user)
      end

      def ensure_initial_admin_access!(root_recording)
        return if access_exists_for_user?(root_recording)

        RecordingStudioAccessible.grant_access(
          recording: root_recording,
          actor: @user,
          role: :admin,
          manager_actor: @actor
        ).value!
      end

      def access_exists_for_user?(root_recording)
        RecordingStudioAccessible::DirectAccessQuery
          .access_recordings_for_actor(recording: root_recording, actor: @user)
          .exists?
      end

      def find_or_create_profile_recording!(root_recording)
        existing_recording = RecordingStudio::Recording
          .where(root_recording: root_recording, parent_recording: root_recording, recordable_type: "RecordingStudioUsers::Profile")
          .where(trashed_at: nil)
          .order(created_at: :asc, id: :asc)
          .first
        return existing_recording if existing_recording

        profile = RecordingStudioUsers::Profile.create!(
          display_name: default_display_name,
          biography: nil,
          locale: nil,
          time_zone: nil
        )

        RecordingStudio.record!(
          action: "created",
          actor: @actor,
          recordable: profile,
          root_recording: root_recording,
          parent_recording: root_recording
        ).recording
      end

      def default_display_name
        return @user.name if @user.respond_to?(:name) && @user.name.present?
        return @user.email.split("@").first.humanize if @user.respond_to?(:email) && @user.email.present?

        "User"
      end
    end
  end
end
