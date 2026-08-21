# frozen_string_literal: true

module RecordingStudioUsers
  module CurrentContext
    extend ActiveSupport::Concern

    included do
      prepend_before_action :recording_studio_users_set_current_actor
      before_action :recording_studio_users_require_current_root
    end

    private

    def recording_studio_users_set_current_actor
      return if respond_to?(:devise_controller?) && devise_controller?

      actor = RecordingStudioUsers.configuration.current_actor_for(controller: self)
      Current.actor = actor if defined?(Current) && Current.respond_to?(:actor=)
    end

    def recording_studio_users_require_current_root
      return if respond_to?(:devise_controller?) && devise_controller?

      actor = RecordingStudioUsers.configuration.current_actor_for(controller: self)
      return unless actor
      return if RecordingStudioAccessible.root_recordings_for(actor: actor).any?

      redirect_to recording_studio_users.onboarding_path
    end
  end
end
