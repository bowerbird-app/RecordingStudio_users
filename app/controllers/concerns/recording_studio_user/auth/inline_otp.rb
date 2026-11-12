# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    # Same-origin answers for a code box that lives in the caller's own modal.
    # A normal browser form still gets the full code page.
    module InlineOtp
      extend ActiveSupport::Concern

      included do
        prepend_before_action :reject_foreign_origin!, only: %i[create submit resend]
      end

      private

      def inline_otp_request?
        turbo_frame_inline? || json_inline?
      end

      def turbo_frame_inline?
        request.headers["Turbo-Frame"] == OtpCodeForm::FRAME_ID
      end

      def json_inline?
        return false if turbo_frame_inline?

        request.format.json? || request.headers["Accept"].to_s.split(",").first.to_s.include?("application/json")
      end

      def reject_foreign_origin!
        origin = request.headers["Origin"].to_s
        return if origin.blank? || origin == request.base_url

        head :forbidden
        deny_auth_framing
      end

      def render_inline_otp(status: :ok)
        return render_inline_json(status: status) if json_inline?

        request.format = :html
        render inline_form, layout: false, status: status
      end

      def render_inline_signed_in(result)
        destination = inline_destination!(result)
        return render_verify_failure(nil) if destination.blank?
        return render json: { ok: true, return_to: destination } if json_inline?

        request.format = :html
        render inline_form(signed_in_return_to: destination), layout: false
      end

      def render_inline_resend(throttled)
        if throttled
          flash.now[:alert] = I18n.t("recording_studio_user.auth.wait_for_code")
          render_inline_otp(status: :too_many_requests)
        else
          flash.now[:notice] = generic_login_notice
          render_inline_otp
        end
      end

      def inline_destination!(result)
        return inline_registration_destination!(result) if registration_challenge?
        return unless eligible_for_direct_sign_in?(result.user)

        clear_pending_auth_email!
        sign_in_user!(result.user)
        after_sign_in_path_for(result.user)
      end

      def inline_registration_destination!(result)
        user = RecordingStudioUser.complete_registration!(user: result.user, challenge: result.challenge)
        accept_pending_terms_on_signup!(user)
        clear_pending_auth_email!
        sign_in_user!(user)
        after_sign_up_path_for(user)
      end

      def inline_form(signed_in_return_to: nil)
        OtpCodeForm.new(
          masked_email: masked_auth_email.to_s,
          alert: flash.now[:alert],
          notice: flash.now[:notice],
          signed_in_return_to: signed_in_return_to
        )
      end

      def render_inline_json(status:)
        body = { ok: status == :ok }
        body[:error] = flash.now[:alert] if flash.now[:alert].present?
        render json: body, status: status
      end
    end
  end
end
