# frozen_string_literal: true

module RecordingStudioUser
  class Configuration
    PROTECTED_PROFILE_ATTRIBUTES = %w[
      id email password password_confirmation encrypted_password reset_password_token
      reset_password_sent_at remember_created_at admin role roles root_id root_recording_id
      recording_id recordable_id recordable_type membership memberships authentication_method
    ].freeze

    AUTHENTICATION_METHODS = %i[password otp].freeze

    attr_accessor :user_class_name, :layout
    attr_reader :mount_path, :profile_route_path, :admin_route_path, :additional_profile_attributes,
                :require_password_confirmation, :otp_enabled, :otp_login_enabled, :otp_registration_enabled,
                :registration_authentication_methods, :password_registration_confirmation, :otp_expires_in,
                :otp_max_attempts, :otp_resend_cooldown, :otp_registration_channels, :otp_login_channels,
                :unconfirmed_user_retention

    def initialize
      @user_class_name = "User"
      @mount_path = "/recording_studio_users"
      @profile_route_path = "profile"
      @admin_route_path = "admin"
      @layout = "application"
      @additional_profile_attributes = []
      @require_password_confirmation = true
      @otp_enabled = false
      @otp_login_enabled = true
      @otp_registration_enabled = true
      @registration_authentication_methods = %i[password otp]
      @password_registration_confirmation = :existing_policy
      @otp_expires_in = 10.minutes
      @otp_max_attempts = 5
      @otp_resend_cooldown = 60.seconds
      @otp_registration_channels = %i[email]
      @otp_login_channels = %i[email push]
      @unconfirmed_user_retention = 7.days
    end

    def otp_enabled=(value)
      @otp_enabled = ActiveModel::Type::Boolean.new.cast(value)
    end

    def otp_enabled?
      otp_enabled
    end

    def otp_login_enabled=(value)
      @otp_login_enabled = ActiveModel::Type::Boolean.new.cast(value)
    end

    def otp_login_enabled?
      otp_login_enabled
    end

    def otp_registration_enabled=(value)
      @otp_registration_enabled = ActiveModel::Type::Boolean.new.cast(value)
    end

    def otp_registration_enabled?
      otp_registration_enabled
    end

    def registration_authentication_methods=(value)
      @registration_authentication_methods = Array(value).map { |method| method.to_sym }.uniq
      validate_registration_authentication_methods!
    end

    def password_registration_confirmation=(value)
      @password_registration_confirmation = value.to_sym
    end

    def otp_expires_in=(value)
      @otp_expires_in = value.to_i.seconds
      validate_positive!(:otp_expires_in, @otp_expires_in)
    end

    def otp_max_attempts=(value)
      @otp_max_attempts = value.to_i
      validate_positive!(:otp_max_attempts, @otp_max_attempts)
    end

    def otp_resend_cooldown=(value)
      @otp_resend_cooldown = value.to_i.seconds
      validate_positive!(:otp_resend_cooldown, @otp_resend_cooldown)
    end

    def otp_registration_channels=(value)
      @otp_registration_channels = Array(value).map(&:to_sym)
    end

    def otp_login_channels=(value)
      @otp_login_channels = Array(value).map(&:to_sym)
    end

    def unconfirmed_user_retention=(value)
      @unconfirmed_user_retention = value.to_i.seconds
      validate_positive!(:unconfirmed_user_retention, @unconfirmed_user_retention)
    end

    def require_password_confirmation=(value)
      @require_password_confirmation = ActiveModel::Type::Boolean.new.cast(value)
    end

    def require_password_confirmation?
      require_password_confirmation
    end

    def mount_path=(value)
      @mount_path = normalize_mount_path(value)
    end

    def profile_route_path=(value)
      @profile_route_path = normalize_relative_path(value)
    end

    def admin_route_path=(value)
      @admin_route_path = normalize_relative_path(value)
    end

    def additional_profile_attributes=(value)
      attributes = Array(value).map { |attribute| attribute.to_s.strip }.reject(&:blank?).uniq
      protected_attributes = attributes & PROTECTED_PROFILE_ATTRIBUTES
      if protected_attributes.any?
        raise ArgumentError, "Protected profile attributes cannot be configured: #{protected_attributes.join(', ')}"
      end

      @additional_profile_attributes = attributes.map(&:to_sym)
    end

    def user_class
      user_class_name.constantize
    rescue NameError
      raise ArgumentError, "Configured user class #{user_class_name.inspect} is unavailable"
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
      validate!
    end

    def validate!
      validate_registration_authentication_methods!
      validate_otp_login_requirement!
    end

    private

    def validate_registration_authentication_methods!
      invalid = registration_authentication_methods - AUTHENTICATION_METHODS
      return if invalid.empty?

      raise ArgumentError, "registration_authentication_methods must only contain password and otp"
    end

    def validate_otp_login_requirement!
      return unless registration_authentication_methods.include?(:otp)
      return if otp_login_enabled?

      raise ArgumentError, "otp_login_enabled must be true when :otp is in registration_authentication_methods"
    end

    def validate_positive!(name, value)
      return if value.positive?

      raise ArgumentError, "#{name} must be positive"
    end

    def normalize_mount_path(value)
      path = value.to_s.strip
      raise ArgumentError, "Mount path cannot be empty" if path.blank?

      normalized = "/#{path.delete_prefix('/').delete_suffix('/')}"
      validate_path!(normalized.delete_prefix("/"))
      normalized
    end

    def normalize_relative_path(value)
      path = value.to_s.strip.delete_prefix("/").delete_suffix("/")
      raise ArgumentError, "Route path cannot be empty" if path.blank?

      validate_path!(path)
      path
    end

    def validate_path!(path)
      return if path.match?(%r{\A[a-zA-Z0-9][a-zA-Z0-9_/-]*\z}) && !path.include?("//")

      raise ArgumentError, "Route path must be a non-empty relative path"
    end
  end
end
