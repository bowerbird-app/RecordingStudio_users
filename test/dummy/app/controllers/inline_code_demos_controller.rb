# frozen_string_literal: true

class InlineCodeDemosController < ApplicationController
  skip_before_action :authenticate_user!
  layout "application"

  def show
    @masked_email = RecordingStudioUser::OtpCodeForm.mask(session[:auth_email]).to_s
  end
end
