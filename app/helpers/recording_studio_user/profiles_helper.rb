# frozen_string_literal: true

module RecordingStudioUser
  module ProfilesHelper
    def profile_display_name(user)
      %i[display_name full_name].each do |method_name|
        value = user.public_send(method_name) if user.respond_to?(method_name)
        return value if value.present?
      end

      name = [user.try(:first_name), user.try(:last_name)].compact_blank.join(" ")
      return name if name.present?
      return user.email if user.respond_to?(:email) && user.email.present?

      t("recording_studio_user.profile.unnamed_user", default: "User")
    end
  end
end
