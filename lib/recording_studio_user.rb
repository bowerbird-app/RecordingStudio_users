# frozen_string_literal: true

require "recording_studio_user/version"
require "recording_studio_user/route_path"
require "recording_studio_user/configuration"
require "recording_studio_user/rails/routes"
require "recording_studio_user/engine"
require "recording_studio_user/admin"
require "recording_studio_user/directory"
require "recording_studio_user/profile_image"
require "recording_studio_user/profile_access"
require "recording_studio_user/otp_setup"
require "recording_studio_user/otp_notifications"
require "recording_studio_user/otp_delivery_payload"
require "recording_studio_user/services/otp_rate_limiter"
require "recording_studio_user/services/issue_otp"
require "recording_studio_user/services/verify_otp"
require "recording_studio_user/services/complete_registration"
require "recording_studio_user/omniauth"

module RecordingStudioUser
  class << self
    def config
      @config ||= Configuration.new
    end
    alias configuration config

    def configure
      yield(config) if block_given?
    end

    def display_name_for(user)
      named_value(user) || composed_name(user) || email_or_fallback(user)
    end

    def mounted_admin_path(context = nil)
      routes = context&.routes
      if routes.respond_to?(:recording_studio_users)
        routes.recording_studio_users.admin_path
      else
        "#{config.mount_path}/#{config.admin_route_path}"
      end
    end

    def people_recordable
      Directory.people_recordable
    end

    def people_root
      Directory.people_root
    end

    def profile_for(user)
      Directory.profile_for(user)
    end

    def profile_recording_for(user)
      Directory.profile_recording_for(user)
    end

    def profile_image_recording_for(user)
      ProfileImage.recording_for(user)
    end

    def attach_profile_image!(...)
      ProfileImage.attach!(...)
    end

    def replace_profile_image!(...)
      ProfileImage.replace!(...)
    end

    def create_user!(...)
      Directory.create_user!(...)
    end

    def record_profile!(...)
      Directory.record_profile!(...)
    end

    def create_unconfirmed_user!(email:)
      Directory.create_unconfirmed_user!(email: email)
    end

    def issue_otp!(...)
      Services::IssueOtp.call(...)
    end

    def verify_otp!(...)
      Services::VerifyOtp.call(...)
    end

    def complete_registration!(...)
      Services::CompleteRegistration.call(...)
    end

    private

    def named_value(user)
      if user.respond_to?(:display_name) && user.method(:display_name).owner.name != "RecordingStudioUser::ProfiledUser"
        user.display_name.presence
      else
        %i[full_name name].filter_map do |method_name|
          user.public_send(method_name) if user.respond_to?(method_name)
        end.find(&:present?)
      end
    end

    def composed_name(user)
      profile = profile_for(user)
      return unless profile

      [profile.first_name, profile.last_name].compact_blank.join(" ").presence
    end

    def email_or_fallback(user)
      return user.email if user.respond_to?(:email) && user.email.present?

      I18n.t("recording_studio_user.profile.unnamed_user", default: "User")
    end
  end
end
