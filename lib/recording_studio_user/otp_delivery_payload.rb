# frozen_string_literal: true

module RecordingStudioUser
  class OtpDeliveryPayload
    def self.call(challenge_id:, delivery:)
      new(challenge_id: challenge_id, delivery: delivery).call
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
      challenge.registration? ? "Verify your email" : "Your sign-in code"
    end

    def body_for(challenge, code)
      minutes = (RecordingStudioUser.config.otp_expires_in / 60).to_i
      if challenge.registration?
        "#{code} is your verification code. It expires in #{minutes} minutes."
      else
        "#{code} is your sign-in code. It expires in #{minutes} minutes."
      end
    end
  end
end
