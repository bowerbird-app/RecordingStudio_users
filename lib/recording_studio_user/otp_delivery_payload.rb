# frozen_string_literal: true

module RecordingStudioUser
  class OtpDeliveryPayload
    def self.call(challenge_id:, delivery:)
      new(challenge_id: challenge_id, delivery: delivery).call
    end

    def self.public_message(challenge_id)
      call(challenge_id: challenge_id, delivery: nil)
    rescue RecordingStudioNotifications::DeliveryPayloadError
      nil
    end

    def initialize(challenge_id:, delivery:)
      @challenge_id = challenge_id
      @delivery = delivery
    end

    def call
      challenge = OtpChallenge.find_by(id: @challenge_id)
      raise RecordingStudioNotifications::DeliveryPayloadError, "challenge unavailable" unless challenge&.deliverable?

      code = challenge.decrypt_delivery_code!
      {
        title: title_for(challenge),
        body: body_for(challenge, code),
        url: nil
      }
    end

    private

    def title_for(challenge)
      if challenge.registration?
        I18n.t("recording_studio_user.otp.verify_your_email")
      else
        I18n.t("recording_studio_user.otp.your_sign_in_code")
      end
    end

    def body_for(challenge, code)
      minutes = (RecordingStudioUser.config.otp_expires_in / 60).to_i
      key = challenge.registration? ? "registration_body" : "login_body"
      I18n.t("recording_studio_user.otp.#{key}", code: code, minutes: minutes)
    end
  end
end
