# frozen_string_literal: true

require "recording_studio_user/engine_routes"

# Auth mount lists many paired GET/POST routes; keep them in one draw block.
# OTP auth and otp_codes follow the same config as recording_studio_user_auth_for
# (initializer values must be set before routes draw / reload).
RecordingStudioUser::Engine.routes.draw do
  RecordingStudioUser::EngineRoutes.draw(self)
end
