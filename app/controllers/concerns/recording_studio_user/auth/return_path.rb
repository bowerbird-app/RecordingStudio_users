# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    # Stores a safe return path and keeps auth responses out of frames.
    module ReturnPath
      extend ActiveSupport::Concern

      included do
        prepend_before_action :remember_auth_return_to
        after_action :deny_auth_framing
      end

      private

      def remember_auth_return_to
        RecordingStudioUser::ReturnTo.remember(session, params[:return_to], popup: params[:popup])
      end

      def deny_auth_framing
        response.headers["X-Frame-Options"] = "DENY"
        append_frame_ancestors!
      end

      def append_frame_ancestors!
        policy = response.headers["Content-Security-Policy"].to_s
        return if policy.include?("frame-ancestors")

        directive = "frame-ancestors 'none'"
        response.headers["Content-Security-Policy"] = [policy.presence, directive].compact.join("; ")
      end

      def complete_signed_in!(user)
        destination = after_auth_path_for(user)
        return render_auth_popup!(destination) if RecordingStudioUser::ReturnTo.popup?(session)

        redirect_to destination
      end

      # One landing path for sign-in and sign-up. A host path wins. Nil keeps
      # the stored return path, or the host root.
      def after_auth_path_for(user)
        callable = RecordingStudioUser.config.after_auth_path
        if callable
          path = callable.call(controller: self, user: user)
          return path unless path.nil?
        end

        stored_auth_return_path(user)
      end

      def render_auth_popup!(destination)
        @auth_popup_destination = destination
        @auth_popup_origins = popup_opener_origins
        RecordingStudioUser::ReturnTo.clear_popup!(session)
        render template: "recording_studio_user/auth/popup_completion"
      end

      def popup_opener_origins
        [request.base_url, *RecordingStudioUser.config.popup_opener_origins].uniq
      end

      def stored_auth_return_path(resource)
        RecordingStudioUser::ReturnTo.accept(stored_location_for(resource)) || main_app.root_path
      end
    end
  end
end
