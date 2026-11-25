# frozen_string_literal: true

module RecordingStudioUser
  module McpCopy
    module Copy
      VIEW = "Requires view access to the admin area."
      EDIT = "Requires edit access to the admin area."

      USERS = "Paged users (page, per_page; same order as the Admin users screen). #{VIEW}".freeze
      USERS_CREATE =
        "Pass a password to call create_user! (Devise user and People-root Profile). " \
        "Omit the password when one-time codes are on to call create_unconfirmed_user! " \
        "and record_profile! for any profile fields. Omit it when they are off and the response is 422. #{EDIT}".freeze
      USERS_SHOW = "One user. Secrets are never returned. #{VIEW}".freeze
      USERS_UPDATE = "Updates profile fields via record_profile!. Email cannot be changed. #{EDIT}".freeze

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
        "users_update" => "Update a user"
      }.freeze

      DESCRIPTIONS = {
        "users" => USERS,
        "users_create" => USERS_CREATE,
        "users_show" => USERS_SHOW,
        "users_update" => USERS_UPDATE
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
        "users_update" => "The user after the change."
      }.freeze
    end
  end
end
