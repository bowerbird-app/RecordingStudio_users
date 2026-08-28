# frozen_string_literal: true

module RecordingStudioUser
  module ProfiledUser
    extend ActiveSupport::Concern

    included do
      before_validation :fill_password_confirmation_when_optional
    end

    def display_name
      RecordingStudioUser.display_name_for(self)
    end

    def profile
      RecordingStudioUser.profile_for(self)
    end

    private

    def fill_password_confirmation_when_optional
      return if RecordingStudioUser.config.require_password_confirmation?
      return unless respond_to?(:password) && respond_to?(:password_confirmation=)
      return if password.blank?

      self.password_confirmation = password
    end
  end
end
