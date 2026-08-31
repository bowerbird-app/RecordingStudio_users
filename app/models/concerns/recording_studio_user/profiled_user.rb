# frozen_string_literal: true

module RecordingStudioUser
  module ProfiledUser
    extend ActiveSupport::Concern

    included do
      before_validation :fill_password_confirmation_when_optional

      has_many :identities,
               class_name: "RecordingStudioUser::Identity",
               foreign_key: :user_id,
               dependent: :destroy,
               inverse_of: :user
    end

    def display_name
      RecordingStudioUser.display_name_for(self)
    end

    def profile
      RecordingStudioUser.profile_for(self)
    end

    def password_required?
      return false if identities.exists? && password.blank? && password_confirmation.blank?

      super
    end

    def password_set?
      RecordingStudioUser::Omniauth.password_set?(self)
    end

    def identity_for(provider)
      identities.find_by(provider: provider.to_s)
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
