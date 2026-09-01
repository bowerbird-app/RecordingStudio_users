# frozen_string_literal: true

module RecordingStudioUser
  module ProfiledUser
    extend ActiveSupport::Concern

    AUTHENTICATION_METHODS = %w[password otp].freeze

    included do
      before_validation :fill_password_confirmation_when_optional
      validates :authentication_method, inclusion: { in: AUTHENTICATION_METHODS }, if: :authentication_method_column?
      after_create :confirm_password_account, if: :password_authentication_method?

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

    def otp_authentication_method?
      authentication_method_column? && authentication_method == "otp"
    end

    def password_authentication_method?
      !authentication_method_column? || authentication_method.blank? || authentication_method == "password"
    end

    def password_required?
      return false if otp_authentication_method?
      return false if identities.exists? && password.blank? && password_confirmation.blank?

      super
    end

    def active_for_authentication?
      return false if otp_authentication_method? && !confirmed?

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

    def authentication_method_column?
      self.class.column_names.include?("authentication_method")
    end

    def fill_password_confirmation_when_optional
      return if RecordingStudioUser.config.require_password_confirmation?
      return unless respond_to?(:password) && respond_to?(:password_confirmation=)
      return if password.blank?

      self.password_confirmation = password
    end

    def confirm_password_account
      return unless RecordingStudioUser.config.password_registration_confirmation == :existing_policy
      return unless password_authentication_method?
      return unless self.class.column_names.include?("confirmed_at")
      return if confirmed_at.present?

      update_column(:confirmed_at, Time.current)
    end
  end
end
