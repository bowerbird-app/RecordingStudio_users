# frozen_string_literal: true

module RecordingStudioUser
  module McpCopy
    module Copy
      USERS = "Paged users (page, per_page; same order as the Admin users screen)."
      USERS_CREATE =
        "Pass a password to call create_user! (Devise user and People-root Profile). " \
        "Omit the password when one-time codes are on to call create_unconfirmed_user! " \
        "and record_profile! for any profile fields. Omit it when they are off and the response is 422."
      USERS_SHOW = "One user. Secrets are never returned."
      USERS_UPDATE = "Updates profile fields via record_profile!. Email cannot be changed."

      TOTAL = "How many user rows exist."
      SIGNUPS = "How many users were created in each period. Pass from, to, and interval."
      TOTAL_OVER_TIME =
        "How many users existed at the end of each period. Pass from, to, and interval."
      BY_METHOD = "How many users registered with each method."
      CONFIRMATION = "How many users are confirmed versus unconfirmed."
      OTP_FAILED =
        "OTP challenges locked after otp_max_attempts wrong codes, " \
        "bucketed by when they were locked (revoked_at). Pass from, to, and interval."

      PAGE = "Offset page. Defaults to 1."
      PER_PAGE = "Rows per page. Defaults to 50, max 100."
      EMAIL = "Login email."
      PASSWORD = "When present, create_user! runs. Omit it when one-time codes are on."
      PASSWORD_CONFIRMATION = "Optional match for password."
      FIRST_NAME = "Given name."
      LAST_NAME = "Family name."
      TIME_ZONE = "Rails time zone name."
      EXTRA_PROFILE = "Allowlisted extras. Hosts may also send those keys at the top level."
      ID = "User id."
      EMAIL_REJECTED = "Not accepted. Sending email returns 422."

      PROFILE_INPUTS = {
        "first_name" => { description: FIRST_NAME },
        "last_name" => { description: LAST_NAME },
        "time_zone" => { description: TIME_ZONE },
        "additional_profile_attributes" => { description: EXTRA_PROFILE }
      }.freeze

      TITLES = {
        "users" => "List users",
        "users_create" => "Create a user",
        "users_show" => "Show a user",
        "users_update" => "Update a user",
        "users-total" => "Total users",
        "users-signups" => "Signups over time",
        "users-total_over_time" => "Total users over time",
        "users-by_method" => "Signups by method",
        "users-confirmation" => "Confirmed vs unconfirmed",
        "otp_challenges-failed_over_time" => "Failed OTP challenges over time"
      }.freeze

      DESCRIPTIONS = {
        "users" => USERS,
        "users_create" => USERS_CREATE,
        "users_show" => USERS_SHOW,
        "users_update" => USERS_UPDATE,
        "users-total" => TOTAL,
        "users-signups" => SIGNUPS,
        "users-total_over_time" => TOTAL_OVER_TIME,
        "users-by_method" => BY_METHOD,
        "users-confirmation" => CONFIRMATION,
        "otp_challenges-failed_over_time" => OTP_FAILED
      }.freeze

      INPUTS = {
        "users" => {
          "page" => { description: PAGE },
          "per_page" => { description: PER_PAGE }
        },
        "users_create" => {
          "email" => { description: EMAIL },
          "password" => { description: PASSWORD },
          "password_confirmation" => { description: PASSWORD_CONFIRMATION }
        }.merge(PROFILE_INPUTS),
        "users_show" => { "id" => { description: ID } },
        "users_update" => {
          "id" => { description: ID },
          "email" => { description: EMAIL_REJECTED }
        }.merge(PROFILE_INPUTS)
      }.freeze

      OUTPUTS = {
        "users" => "The matching users.",
        "users_create" => "The new user.",
        "users_show" => "The user.",
        "users_update" => "The user after the change.",
        "users-total" => "The user count.",
        "users-signups" => "Signups in each period.",
        "users-total_over_time" => "User count at the end of each period.",
        "users-by_method" => "Signup counts by method.",
        "users-confirmation" => "Confirmed and unconfirmed counts.",
        "otp_challenges-failed_over_time" => "Locked OTP challenges in each period."
      }.freeze
    end
  end
end
