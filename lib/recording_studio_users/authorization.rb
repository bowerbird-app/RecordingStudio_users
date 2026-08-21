# frozen_string_literal: true

module RecordingStudioUsers
  module Authorization
    ROLES = %w[view edit admin].freeze
    SESSION_KEY = "recording_studio_users_operating_roles"
    MODES = %i[both operating ceiling].freeze

    class NotAuthorized < StandardError; end

    class << self
      def current_operating_role(actor:, recording:, session: nil, operating_role: nil)
        ceiling = RecordingStudioAccessible.role_for(actor: actor, recording: recording)&.to_s
        return unless ROLES.include?(ceiling)

        requested = operating_role.presence || stored_role(session, recording)
        clamp(requested, ceiling)
      end

      def set_operating_role!(actor:, recording:, role:, session:)
        ceiling = RecordingStudioAccessible.role_for(actor: actor, recording: recording)&.to_s
        normalized = role.to_s
        raise NotAuthorized, "That operating role is not available" unless allowed_role?(normalized, ceiling)

        session[SESSION_KEY] ||= {}
        session[SESSION_KEY][recording.id.to_s] = normalized
        normalized.to_sym
      end

      def authorized_operating?(actor:, recording:, role:, session: nil, operating_role: nil)
        current = current_operating_role(
          actor: actor,
          recording: recording,
          session: session,
          operating_role: operating_role
        )
        allowed_role?(role.to_s, current&.to_s)
      end

      def authorize!(actor:, recording:, role:, mode: :both, session: nil, operating_role: nil)
        normalized_mode = mode.to_sym
        raise ArgumentError, "Unknown authorization mode: #{mode}" unless MODES.include?(normalized_mode)

        ceiling_allowed = RecordingStudioAccessible.authorized?(
          actor: actor,
          recording: recording,
          role: role
        )
        operating_allowed = authorized_operating?(
          actor: actor,
          recording: recording,
          role: role,
          session: session,
          operating_role: operating_role
        )

        allowed = case normalized_mode
                  when :ceiling then ceiling_allowed
                  when :operating then operating_allowed
                  else ceiling_allowed && operating_allowed
                  end
        raise NotAuthorized, "Your current role cannot do that" unless allowed

        true
      end

      private

      def stored_role(session, recording)
        return unless session

        session[SESSION_KEY]&.[](recording.id.to_s)
      end

      def clamp(requested, ceiling)
        normalized = requested.to_s
        return ceiling.to_sym unless ROLES.include?(normalized)
        return ceiling.to_sym unless allowed_role?(normalized, ceiling)

        normalized.to_sym
      end

      def allowed_role?(required, actual)
        required_index = ROLES.index(required.to_s)
        actual_index = ROLES.index(actual.to_s)
        required_index && actual_index && actual_index >= required_index
      end
    end
  end
end
