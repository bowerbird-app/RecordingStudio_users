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

    def initialize(masked_email:, alert: nil, notice: nil, signed_in_return_to: nil,
                   csrf_param: nil, csrf_token: nil)
      @masked_email = masked_email
      @alert = alert
      @notice = notice
      @signed_in_return_to = signed_in_return_to
      @csrf_param = csrf_param
      @csrf_token = csrf_token
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
        inline_terms: inline_terms,
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

    def inline_terms
      return if signed_in?
      return unless helpers.session[:otp_purpose].to_s == "registration"

      helpers.recording_studio_user_inline_terms
    end

    def signed_in_script
      detail = ERB::Util.json_escape(signed_in_detail.to_json)
      "var detail = #{detail};" \
        "var param = document.querySelector('meta[name=\"csrf-param\"]');" \
        "var token = document.querySelector('meta[name=\"csrf-token\"]');" \
        "if (param && detail.csrf_param) param.setAttribute('content', detail.csrf_param);" \
        "if (token && detail.csrf_token) token.setAttribute('content', detail.csrf_token);" \
        "document.dispatchEvent(new CustomEvent('recording_studio_user:signed_in', " \
        "{ bubbles: true, detail: detail }));"
    end

    def signed_in_detail
      {
        "return_to" => @signed_in_return_to,
        "csrf_param" => @csrf_param,
        "csrf_token" => @csrf_token
      }
    end
  end
end
