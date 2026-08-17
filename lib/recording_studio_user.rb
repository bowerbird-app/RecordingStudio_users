# frozen_string_literal: true

require "recording_studio_user/version"
require "recording_studio_user/configuration"
require "recording_studio_user/engine"
require "recording_studio_user/admin"

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
      if user.respond_to?(:display_name) && user.method(:display_name).owner.name != "RecordingStudioUser::ProfiledUser"
        value = user.display_name
        return value if value.present?
      end

      %i[full_name name].each do |method_name|
        next unless user.respond_to?(method_name)

        value = user.public_send(method_name)
        return value if value.present?
      end

      name = [user.try(:first_name), user.try(:last_name)].compact_blank.join(" ")
      return name if name.present?
      return user.email if user.respond_to?(:email) && user.email.present?

      I18n.t("recording_studio_user.profile.unnamed_user", default: "User")
    end

    def mounted_admin_path(context = nil)
      routes = context&.routes
      if routes.respond_to?(:recording_studio_users)
        routes.recording_studio_users.admin_path
      else
        "#{config.mount_path}/#{config.admin_route_path}"
      end
    end
  end
end
