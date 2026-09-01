# frozen_string_literal: true

require "active_support/core_ext/numeric/time"

module RecordingStudioUser
  class Configuration
    PROTECTED_PROFILE_ATTRIBUTES = %w[
      id email password password_confirmation encrypted_password reset_password_token
      reset_password_sent_at remember_created_at admin role roles root_id root_recording_id
      recording_id recordable_id recordable_type membership memberships authentication_method
    ].freeze

    AUTHENTICATION_METHODS = %i[password otp].freeze

    # otp_login_enabled has its own writer because it must stay compatible with
    # the registration methods.
    BOOLEAN_SETTINGS = %i[require_password_confirmation otp_enabled otp_registration_enabled].freeze
    DURATION_SETTINGS = %i[otp_expires_in otp_resend_cooldown unconfirmed_user_retention].freeze
    CHANNEL_SETTINGS = %i[otp_registration_channels otp_login_channels].freeze

    DEFAULTS = {
      user_class_name: "User",
      mount_path: "/recording_studio_users",
      profile_route_path: "profile",
      admin_route_path: "admin",
      layout: "application",
      additional_profile_attributes: [],
      require_password_confirmation: true,
      otp_enabled: false,
      otp_login_enabled: true,
      otp_registration_enabled: true,
      registration_authentication_methods: %i[password otp],
      password_registration_confirmation: :existing_policy,
      otp_expires_in: 10.minutes,
      otp_max_attempts: 5,
      otp_resend_cooldown: 60.seconds,
      otp_registration_channels: %i[email],
      otp_login_channels: %i[email push],
      unconfirmed_user_retention: 7.days
    }.freeze

    attr_accessor :user_class_name, :layout
    attr_reader(*(DEFAULTS.keys - %i[user_class_name layout]))

    BOOLEAN_SETTINGS.each do |setting|
      define_method("#{setting}=") do |value|
        instance_variable_set("@#{setting}", ActiveModel::Type::Boolean.new.cast(value))
      end

      define_method("#{setting}?") { public_send(setting) }
    end

    DURATION_SETTINGS.each do |setting|
      define_method("#{setting}=") do |value|
        duration = value.to_i.seconds
        validate_positive!(setting, duration)
        instance_variable_set("@#{setting}", duration)
      end
    end

    CHANNEL_SETTINGS.each do |setting|
      define_method("#{setting}=") do |value|
        instance_variable_set("@#{setting}", Array(value).map(&:to_sym))
      end
    end

    def initialize
      DEFAULTS.each { |setting, value| instance_variable_set("@#{setting}", value) }
    end

    def otp_login_enabled=(value)
      @otp_login_enabled = ActiveModel::Type::Boolean.new.cast(value)
      validate_otp_login_requirement!
    end

    def otp_login_enabled?
      otp_login_enabled
    end

    def otp_max_attempts=(value)
      attempts = value.to_i
      validate_positive!(:otp_max_attempts, attempts)
      @otp_max_attempts = attempts
    end

    def registration_authentication_methods=(value)
      @registration_authentication_methods = Array(value).map(&:to_sym).uniq
      validate_registration_authentication_methods!
      validate_otp_login_requirement!
    end

    def password_registration_confirmation=(value)
      @password_registration_confirmation = value.to_sym
    end

    def mount_path=(value)
      @mount_path = RoutePath.mount(value)
    end

    def profile_route_path=(value)
      @profile_route_path = RoutePath.relative(value)
    end

    def admin_route_path=(value)
      @admin_route_path = RoutePath.relative(value)
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

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
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
  end
end
