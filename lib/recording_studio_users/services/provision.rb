# frozen_string_literal: true

module RecordingStudioUsers
  module Services
    class Provision
      def self.call(...)
        new(...).call
      end

      def initialize(user:, actor: nil)
        @user = user
        @requested_actor = actor
      end

      def call
        return Result.failure("User must be persisted") unless user&.persisted?

        value = user.class.transaction(requires_new: true) do
          user.lock!
          actor = resolve_actor!
          user_root = find_or_create_user_root!
          root_recording = RecordingStudio.root_recording_for(user_root)
          establish_access!(user_root, root_recording, actor)
          create_profile!(root_recording, actor)
          RecordingStudioUsers.validate_user_profile!(user)
          user_root
        end
        Result.success(value)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::RecordNotFound,
             ActiveRecord::StatementInvalid, RecordingStudioUsers::Error, ArgumentError => e
        Result.failure(e, errors: validation_errors(e))
      end

      private

      attr_reader :user, :requested_actor

      def resolve_actor!
        actor = requested_actor || RecordingStudioUsers.call_configured(
          RecordingStudioUsers.configuration.provisioning_actor,
          user:
        )
        raise ConfigurationError, "A persisted provisioning actor is required" unless actor&.persisted?

        actor
      end

      def find_or_create_user_root!
        UserRoot.find_or_create_by!(user_type: user.class.base_class.name, user_id: user.id) do |root|
          root.user = user
        end
      end

      def establish_access!(user_root, root_recording, actor)
        grants = RecordingStudioAccessible.access_recordings_for(root_recording).to_a
        return validate_existing_grant!(grants) if grants.any?

        result = ProvisioningAuthorization.with_context(user:, user_root:, root_recording:, actor:) do
          RecordingStudioAccessible.grant_access(
            recording: root_recording,
            actor: user,
            role: :admin,
            manager_actor: actor
          )
        end
        raise Error, result.error if result.failure?

        grants = RecordingStudioAccessible.access_recordings_for(root_recording).to_a
        validate_existing_grant!(grants)
        raise TopologyError, "Accessible returned an unexpected grant" unless grants.first == result.value
      end

      def validate_existing_grant!(grants)
        raise TopologyError, "Private root must have exactly one active direct grant" unless grants.one?

        access = grants.first.recordable
        return if access.actor == user && access.role.to_s == "admin"

        raise TopologyError, "Private root has a conflicting access grant"
      end

      def create_profile!(root_recording, actor)
        profiles = RecordingStudio::Recording.unscoped.where(
          root_recording_id: root_recording.id,
          parent_recording_id: root_recording.id,
          recordable_type: "RecordingStudioUsers::Profile",
          trashed_at: nil
        ).limit(2).to_a
        raise TopologyError, "Private root has duplicate Profiles" if profiles.many?
        return profiles.first if profiles.one?

        root_recording.record(Profile, actor:, parent_recording: root_recording)
      end

      def validation_errors(error)
        return error.record.errors.full_messages if error.respond_to?(:record) && error.record.respond_to?(:errors)

        []
      end
    end
  end
end
