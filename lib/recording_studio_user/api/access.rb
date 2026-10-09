# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Access
      module_function

      ResolverContext = Struct.new(:controller)

      def admin_root_recording
        return unless defined?(RecordingStudioAdmin)

        resolver = RecordingStudioAdmin.configuration.access_recording_resolver
        return unless resolver

        resolver.call(ResolverContext.new(nil))
      end

      def actor_for(context)
        context&.access_grant&.actor
      end

      def can_view?(context)
        authorized_on_admin_root?(context, :view)
      end

      def authorize_view!(context)
        return if can_view?(context)

        deny!
      end

      def deny!
        raise authorization_error, "API access grant is not authorized for this capability"
      end

      def authorization_error
        if defined?(RecordingStudioApi::AuthorizationError)
          RecordingStudioApi::AuthorizationError
        else
          AuthorizationDenied
        end
      end

      def authorized_on_admin_root?(context, role)
        actor = actor_for(context)
        recording = admin_root_recording
        return false if actor.blank? || recording.blank?
        return false unless defined?(RecordingStudioAccessible)

        RecordingStudioAccessible.authorized?(
          actor: actor,
          recording: recording,
          role: role
        )
      end
    end

    class AuthorizationDenied < StandardError; end
  end
end
