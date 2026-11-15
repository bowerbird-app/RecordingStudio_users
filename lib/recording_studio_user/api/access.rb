# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Access
      module_function

      def admin_root_recording
        return unless defined?(RecordingStudioAccessible)

        RecordingStudioAccessible.admin_root
      end

      def actor_for(context)
        context&.access_grant&.actor
      end

      def can_edit?(context)
        authorized_on_admin_root?(context, :edit)
      end

      def can_view?(context)
        authorized_on_admin_root?(context, :view)
      end

      def authorize_edit!(context)
        return if can_edit?(context)

        deny!
      end

      def authorize_view!(context)
        return if can_view?(context)

        deny!
      end

      def deny!
        raise RecordingStudioApi::AuthorizationError,
              "API access grant is not authorized for this capability"
      end

      def authorized_on_admin_root?(context, role)
        actor = actor_for(context)
        return false if actor.blank? || !defined?(RecordingStudioAccessible)

        RecordingStudioAccessible.admin?(actor: actor, role: role)
      end
    end
  end
end
