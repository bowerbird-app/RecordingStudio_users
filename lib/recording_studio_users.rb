# frozen_string_literal: true

require "recording_studio_users/version"
require "recording_studio_accessible"
require "recording_studio_users/engine"
require "recording_studio_users/configuration"
require "recording_studio_users/user"
require "recording_studio_users/services/base_service"
require "recording_studio_users/services/provision_user"
require "recording_studio_users/services/grant_membership"
require "recording_studio_users/services/change_membership_role"
require "recording_studio_users/services/revoke_membership"

module RecordingStudioUsers
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def user_class
      configuration.user_class
    end

    def provision(user, actor: nil)
      Services::ProvisionUser.call(user: user, actor: actor || configuration.provisioning_actor_for(user: user)).value!
    end

    def provisioned?(user)
      user_root_for(user).present? && profile_recording_for(user).present?
    end

    def user_root_for(user)
      return unless user&.persisted?

      RecordingStudioUsers::UserRoot.find_by(user: user)
    end

    def profile_recording_for(user)
      root_recording = user_root_recording_for(user)
      return unless root_recording

      RecordingStudio::Recording
        .where(root_recording: root_recording, parent_recording: root_recording, recordable_type: "RecordingStudioUsers::Profile")
        .where(trashed_at: nil)
        .order(created_at: :asc, id: :asc)
        .first
    end

    def profile_for(user)
      profile_recording_for(user)&.recordable
    end

    def avatar_recording_for(user)
      profile_recording = profile_recording_for(user)
      return unless profile_recording
      return unless defined?(RecordingStudioAttachable)

      if RecordingStudioAttachable.respond_to?(:active_attachment_recording_for)
        return RecordingStudioAttachable.active_attachment_recording_for(recording: profile_recording)
      end

      nil
    end

    def validate_user_profile!(user)
      raise ArgumentError, "User must be persisted" unless user&.persisted?

      root = user_root_for(user)
      raise "Missing user root for #{user_label_for_errors(user)}" unless root

      raise "Missing profile recording for #{user_label_for_errors(user)}" unless profile_recording_for(user)

      true
    end

    private

    def user_root_recording_for(user)
      user_root = user_root_for(user)
      return unless user_root

      RecordingStudio.root_recording_for(user_root)
    end

    def user_label_for_errors(user)
      configuration.user_label_for(user: user)
    rescue StandardError
      user.class.name
    end
  end
end
