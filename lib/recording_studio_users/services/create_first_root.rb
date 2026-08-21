# frozen_string_literal: true

module RecordingStudioUsers
  module Services
    class CreateFirstRoot
      def self.call(...)
        new(...).call
      end

      def initialize(name:, actor:, controller: nil, device_key: nil)
        @name = name.to_s.strip
        @actor = actor
        @controller = controller
        @device_key = device_key
      end

      def call
        return Result.failure("Give your workspace a name") if @name.blank?
        return Result.failure("Sign in before creating a workspace") unless @actor&.persisted?

        root_recording = nil
        bootstrap_result = nil

        @actor.with_lock do
          return Result.failure("You already have a workspace") if accessible_roots.any?

          root_recordable = RecordingStudioUsers.configuration.create_root(name: @name, actor: @actor)
          root_recording = RecordingStudio.root_recording_for(root_recordable)
          raise ActiveRecord::Rollback unless owned_root?(root_recording)

          bootstrap_result = RecordingStudioAccessible.bootstrap_owner_access!(
            recording: root_recording,
            actor: @actor
          )
          raise ActiveRecord::Rollback if bootstrap_result.failure?
        end

        return Result.failure("That root cannot be bootstrapped") unless owned_root?(root_recording)
        unless bootstrap_result&.success?
          return Result.failure(bootstrap_result&.error || "Could not create your workspace")
        end

        select_root(root_recording)

        Result.success(root_recording)
      rescue ActiveRecord::RecordInvalid => e
        Result.failure(e.record.errors.full_messages.to_sentence)
      rescue StandardError => e
        Rails.logger.error("RecordingStudioUsers could not create first root: #{e.class}")
        Result.failure("Could not create your workspace")
      end

      private

      def accessible_roots
        RecordingStudioAccessible.root_recordings_for(actor: @actor)
      end

      def owned_root?(recording)
        recording && RecordingStudio.root_recording?(recording) && !RecordingStudio.shared_root?(recording)
      rescue StandardError
        false
      end

      def switch_root(root_recording)
        RecordingStudio::RootSwitchable.switch_root(
          root_recording_id: root_recording.id,
          scope_key: RecordingStudioUsers.configuration.root_scope_key,
          controller: @controller,
          actor: @actor,
          device_key: @device_key
        )
      end

      def select_root(root_recording)
        result = switch_root(root_recording)
        return if result.success?

        Rails.logger.warn("RecordingStudioUsers could not select new root: #{result.errors.to_sentence}")
      rescue StandardError => e
        Rails.logger.warn("RecordingStudioUsers could not select new root: #{e.class}")
      end
    end
  end
end
