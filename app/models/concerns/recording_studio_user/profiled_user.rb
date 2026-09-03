# frozen_string_literal: true

module RecordingStudioUser
  module ProfiledUser
    extend ActiveSupport::Concern

    REGISTERED_WITH_VALUES = %w[password otp].freeze

    included do
      before_validation :fill_password_confirmation_when_optional
      validates :registered_with, inclusion: { in: REGISTERED_WITH_VALUES }, if: :registered_with_column?
      after_create :confirm_password_account, if: :registered_with_password?

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

    def registered_with_otp?
      registered_with_column? && registered_with == "otp"
    end

    def registered_with_password?
      !registered_with_column? || registered_with.blank? || registered_with == "password"
    end

    def password_required?
      return false if registered_with_otp?
      return false if identities.exists? && password.blank? && password_confirmation.blank?

      super
    end

    def active_for_authentication?
      return false if registered_with_otp? && !confirmed?

      super
    end

    def password_set?
      RecordingStudioUser::Omniauth.password_set?(self)
    end

    # Only providers the host still configures can actually sign someone in.
    def usable_identities
      identities.for_configured_providers
    end

    def identity_for(provider)
      identities.find_by(provider: provider.to_s)
    end

    private

    def registered_with_column?
      self.class.column_names.include?("registered_with")
    end

    def fill_password_confirmation_when_optional
      return if RecordingStudioUser.config.require_password_confirmation?
      return unless respond_to?(:password) && respond_to?(:password_confirmation=)
      return if password.blank?

      self.password_confirmation = password
    end

    def confirm_password_account
      return unless RecordingStudioUser.config.password_registration_confirmation == :existing_policy
      return unless registered_with_password?
      return unless self.class.column_names.include?("confirmed_at")
      return if confirmed_at.present?

      update_column(:confirmed_at, Time.current)
    end
  end
end
