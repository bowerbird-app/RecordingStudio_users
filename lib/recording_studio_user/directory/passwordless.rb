# frozen_string_literal: true

module RecordingStudioUser
  module Directory
    module_function

    def create_passwordless_user!(email:, actor: nil, **attributes)
      raise ArgumentError, "email is required" if email.blank?

      profile_attrs = attributes.extract!(*PROFILE_ATTRIBUTE_KEYS)
      user = nil
      ActiveRecord::Base.transaction do
        user = save_passwordless_account!(email, attributes)
        record_profile!(user, actor: actor, **passwordless_profile_attributes(user, profile_attrs))
      end
      user
    end

    def save_passwordless_account!(email, attributes)
      user = RecordingStudioUser.config.user_class.new(email: email, **passwordless_user_attributes(attributes))
      user.skip_confirmation_notification! if user.respond_to?(:skip_confirmation_notification!)
      user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
      user.save!
      user
    end

    def passwordless_user_attributes(attributes)
      attrs = attributes.symbolize_keys.except(:password, :password_confirmation)
      klass = RecordingStudioUser.config.user_class
      return attrs unless klass.column_names.include?("registered_with")

      attrs.merge(registered_with: "otp")
    end

    def passwordless_profile_attributes(user, profile_attrs)
      defaults = Profile.default_attributes_for(user)
      profile_attrs.merge(
        first_name: profile_attrs[:first_name].presence || defaults[:first_name],
        time_zone: profile_attrs.key?(:time_zone) ? profile_attrs[:time_zone] : defaults[:time_zone]
      )
    end
  end
end
