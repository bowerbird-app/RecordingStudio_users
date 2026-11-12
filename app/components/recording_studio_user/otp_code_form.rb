# frozen_string_literal: true

module RecordingStudioUser
  # The code box a sibling gem drops into its own modal. No logo, title, or page shell.
  class OtpCodeForm < ViewComponent::Base
    FRAME_ID = "recording_studio_user_otp_inline"

    def self.mask(email)
      local, domain = email.to_s.split("@", 2)
      return if local.blank? || domain.blank?

      "#{local[0]}***@#{domain}"
    end

    def initialize(masked_email:, alert: nil, notice: nil, signed_in_return_to: nil)
      @masked_email = masked_email
      @alert = alert
      @notice = notice
      @signed_in_return_to = signed_in_return_to
      super()
    end

    def call
      helpers.render(partial: "recording_studio_user/otp/inline_code_form", locals: form_locals)
    end

    def form_locals
      {
        masked_email: @masked_email,
        alert: @alert,
        notice: @notice,
        signed_in_return_to: @signed_in_return_to,
        hint: hint,
        signed_in_script: signed_in? ? signed_in_script : nil
      }
    end

    def signed_in?
      @signed_in_return_to.present?
    end

    def hint
      return I18n.t("recording_studio_user.otp_challenge.signed_in") if signed_in?
      return I18n.t("recording_studio_user.otp_challenge.inline_hint", email: @masked_email) if @masked_email.present?

      I18n.t("recording_studio_user.otp_challenge.enter_code")
    end

    def signed_in_script
      destination = ERB::Util.json_escape(@signed_in_return_to.to_json)
      %(document.dispatchEvent(new CustomEvent("recording_studio_user:signed_in", ) +
        %({ bubbles: true, detail: { return_to: #{destination} } })))
    end
  end
end
