# frozen_string_literal: true

module RecordingStudioUser
  class OtpCodesController < ApplicationController
    before_action :authenticate_user!

    def show
      @challenge = OtpChallenge.find_by(id: params[:id], user: current_user)
      return head :not_found unless @challenge&.login?

      @code = @challenge.decrypt_delivery_code! if @challenge.deliverable?
    end
  end
end
