# frozen_string_literal: true

require "active_support/core_ext/numeric/time"

module RecordingStudioUser
  class Configuration
    PROTECTED_PROFILE_ATTRIBUTES = %w[
      id email password password_confirmation encrypted_password reset_password_token
      reset_password_sent_at remember_created_at admin role roles root_id root_recording_id
      recording_id recordable_id recordable_type membership memberships registered_with
    ].freeze

    AUTHENTICATION_METHODS = %i[password otp].freeze
    PRIMARY_LOGIN_TYPES = %i[email otp].freeze
    AUTH_LOGO_TYPES = %i[square wide].freeze
    POPUP_ORIGIN = %r{\Ahttps?://[a-zA-Z0-9.-]+(?::\d+)?\z}
    VARIANT_NAME = /\A[a-z][a-z0-9_]{0,40}\z/
    I18N_KEY = /\A[a-z0-9_]+(?:\.[a-z0-9_]+){0,8}\z/
    I18N_KEY_MAX = 80

    # otp_login_enabled has its own writer because it must stay compatible with
    # the registration methods.
    BOOLEAN_SETTINGS = %i[require_password_confirmation otp_enabled otp_registration_enabled].freeze
    DURATION_SETTINGS = %i[
      otp_expires_in otp_resend_cooldown unconfirmed_user_retention
      otp_lockout_window otp_lockout_duration
      password_sign_in_period password_reset_period
      password_lockout_window password_lockout_duration
    ].freeze
    POSITIVE_INTEGER_SETTINGS = %i[
      otp_lockout_max_failures password_lockout_max_failures
      password_sign_in_email_limit password_sign_in_ip_limit
      password_reset_email_limit password_reset_ip_limit
      minimum_password_length
    ].freeze
    CHANNEL_SETTINGS = %i[otp_registration_channels otp_login_channels].freeze

    DEFAULTS = {
      user_class_name: "User",
      mount_path: "/recording_studio_users",
      profile_route_path: "profile",
      admin_route_path: "admin",
      layout: nil,
      additional_profile_attributes: [:locale],
      require_password_confirmation: false,
      primary_login_type: :email,
      auth_logo: :square,
      otp_enabled: false,
      otp_login_enabled: true,
      otp_registration_enabled: true,
      registration_authentication_methods: %i[password otp],
      otp_expires_in: 10.minutes,
      otp_max_attempts: 5,
      otp_lockout_max_failures: 10,
      otp_lockout_window: 1.hour,
      otp_lockout_duration: 1.hour,
      otp_resend_cooldown: 60.seconds,
      otp_registration_channels: %i[email],
      otp_login_channels: %i[email push],
      unconfirmed_user_retention: 7.days,
      omniauth_create_account: true,
      password_lockout_max_failures: 10,
      password_lockout_window: 1.hour,
      password_lockout_duration: 1.hour,
      password_sign_in_email_limit: 5,
      password_sign_in_ip_limit: 10,
      password_sign_in_period: 3.minutes,
      password_reset_email_limit: 3,
      password_reset_ip_limit: 10,
      password_reset_period: 15.minutes,
      minimum_password_length: 12
    }.freeze

    attr_accessor :user_class_name, :auth_site_root_resolver, :after_auth_path
    attr_reader(
      :layout,
      *(DEFAULTS.keys - %i[user_class_name layout]),
      :after_registration_hooks,
      :auth_body_start_partial,
      :signup_notice_partials,
      :popup_opener_origins,
      :sign_up_variants
    )

    BOOLEAN_SETTINGS.each do |setting|
      define_method("#{setting}=") do |value|
        previous = instance_variable_get("@#{setting}")
        instance_variable_set("@#{setting}", ActiveModel::Type::Boolean.new.cast(value))
        validate_primary_login_type! if %i[otp_enabled otp_registration_enabled].include?(setting)
      rescue ArgumentError
        instance_variable_set("@#{setting}", previous)
        raise
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

    POSITIVE_INTEGER_SETTINGS.each do |setting|
      define_method("#{setting}=") do |value|
        number = value.to_i
        validate_positive!(setting, number)
        instance_variable_set("@#{setting}", number)
      end
    end

    CHANNEL_SETTINGS.each do |setting|
      define_method("#{setting}=") do |value|
        instance_variable_set("@#{setting}", Array(value).map(&:to_sym))
      end
    end

    def layout=(value)
      @layout = RecordingStudio::Layout.accept(value)
    end

    def initialize
      DEFAULTS.each { |setting, value| instance_variable_set("@#{setting}", value) }
      @login_title = nil
      @auth_body_start_partial = nil
      @signup_notice_partials = []
      @omniauth_providers = {}
      @auth_site_root_resolver = nil
      @after_auth_path = nil
      @after_registration_hooks = []
      @popup_opener_origins = []
      assign_sign_up_variants(empty_sign_up_variants)
    end

    # Register a host callback that runs after a successful sign-up (password,
    # OAuth new-user, or OTP). Accepts a callable or a class-name string whose
    # constant responds to .call. Signature: call(user:, method:). Multiple
    # registrations are allowed; each runs in registration order.
    def after_registration(hook = nil, &block)
      callable = hook || block
      raise ArgumentError, "after_registration hook or block is required" if callable.nil?
      unless callable.respond_to?(:call) || callable.is_a?(String)
        raise ArgumentError, "after_registration must be a callable or class-name string"
      end

      @after_registration_hooks << callable
      callable
    end

    def login_title
      @login_title.presence || I18n.t("recording_studio_user.auth.login_title")
    end

    def otp_login_enabled=(value)
      previous = @otp_login_enabled
      @otp_login_enabled = ActiveModel::Type::Boolean.new.cast(value)
      validate_otp_login_requirement!
      validate_primary_login_type!
    rescue ArgumentError
      @otp_login_enabled = previous
      raise
    end

    def otp_login_enabled?
      otp_login_enabled
    end

    def primary_login_type=(value)
      previous = @primary_login_type
      @primary_login_type = value.to_sym
      validate_primary_login_type!
    rescue ArgumentError
      @primary_login_type = previous
      raise
    end

    def primary_login_type_email?
      primary_login_type == :email
    end

    def primary_login_type_otp?
      primary_login_type == :otp
    end

    def auth_logo=(value)
      previous = @auth_logo
      @auth_logo = value.to_sym
      validate_auth_logo!
    rescue ArgumentError
      @auth_logo = previous
      raise
    end

    def auth_logo_square?
      auth_logo == :square
    end

    def auth_logo_wide?
      auth_logo == :wide
    end

    def otp_max_attempts=(value)
      attempts = value.to_i
      validate_positive!(:otp_max_attempts, attempts)
      @otp_max_attempts = attempts
    end

    def registration_authentication_methods=(value)
      previous = @registration_authentication_methods
      @registration_authentication_methods = Array(value).map(&:to_sym).uniq
      validate_registration_authentication_methods!
      validate_otp_login_requirement!
      validate_primary_login_type!
    rescue ArgumentError
      @registration_authentication_methods = previous
      raise
    end

    def password_registration_confirmation=(_value)
      raise ArgumentError,
            "password_registration_confirmation has been removed. " \
            "Password signups confirm with an email code. Delete this setting."
    end

    def password_registration_allowed?
      !primary_login_type_otp? && registration_authentication_methods.include?(:password)
    end

    def sign_in_code_allowed?
      password_registration_allowed? ||
        (otp_enabled? && (otp_login_enabled? || otp_registration_enabled?))
    end

    def login_title=(value)
      @login_title = value.to_s.strip.presence
    end

    def auth_body_start_partial=(value)
      @auth_body_start_partial = value&.to_s&.strip.presence
    end

    # Partial paths rendered next to the submit button on signup and other
    # unsigned auth forms. Same path style as auth_body_start_partial.
    # Default is an empty list, which renders nothing.
    def signup_notice_partials=(value)
      @signup_notice_partials = Array(value).map { |partial| partial.to_s.strip }.reject(&:empty?)
    end

    def sign_up_variants=(value)
      assign_sign_up_variants(compile_sign_up_variants(value))
    end

    def sign_up_variant_name(raw)
      text = variant_request_text(raw)
      return if text.nil? || !@sign_up_variant_index.key?(text)

      text
    end

    def sign_up_heading(raw)
      entry = @sign_up_variant_index[sign_up_variant_name(raw)]
      title = entry && translated_sign_up_key(entry[:title])
      return default_sign_up_heading unless title

      { title: title, subtitle: translated_sign_up_key(entry[:subtitle]) }
    end

    def popup_opener_origins=(value)
      origins = normalized_popup_origins(value)
      raise ArgumentError, "popup opener origin must be an http(s) origin" unless popup_origins_valid?(origins)

      @popup_opener_origins = origins
    end

    def omniauth_create_account=(value)
      @omniauth_create_account = ActiveModel::Type::Boolean.new.cast(value)
    end

    def omniauth_create_account?
      omniauth_create_account
    end

    def omniauth_providers=(value)
      providers = value.respond_to?(:to_h) ? value.to_h : {}
      @omniauth_providers = providers.each_with_object({}) do |(name, options), memo|
        key = name.to_sym
        opts = (options || {}).to_h.transform_keys(&:to_sym)
        memo[key] = opts
      end
    end

    # Buttons and Devise strategies follow credentials when this hash is empty.
    # An explicit non-empty hash still wins, but blank client secrets are skipped.
    def omniauth_providers
      RecordingStudioUser::Omniauth.resolve_providers(@omniauth_providers)
    end

    def omniauth_provider_names
      omniauth_providers.keys.map(&:to_sym)
    end

    def omniauth_configured?
      omniauth_providers.any?
    end

    def omniauth_provider_configured?(provider)
      omniauth_providers.key?(provider.to_sym)
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
      validate_primary_login_type!
      validate_auth_logo!
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

    def validate_primary_login_type!
      unless PRIMARY_LOGIN_TYPES.include?(primary_login_type)
        raise ArgumentError, "primary_login_type must be :email or :otp"
      end
      return if primary_login_type == :email

      validate_otp_primary_login_type!
    end

    def validate_otp_primary_login_type!
      raise ArgumentError, "primary_login_type :otp requires otp_enabled" unless otp_enabled?
      raise ArgumentError, "primary_login_type :otp requires otp_login_enabled" unless otp_login_enabled?
      raise ArgumentError, "primary_login_type :otp requires otp_registration_enabled" unless
        otp_registration_enabled?
      return if registration_authentication_methods.include?(:otp)

      raise ArgumentError, "primary_login_type :otp requires :otp in registration_authentication_methods"
    end

    def validate_auth_logo!
      return if AUTH_LOGO_TYPES.include?(auth_logo)

      raise ArgumentError, "auth_logo must be :square or :wide"
    end

    def validate_positive!(name, value)
      return if value.positive?

      raise ArgumentError, "#{name} must be positive"
    end

    def compile_sign_up_variants(value)
      return empty_sign_up_variants if value.nil?
      raise ArgumentError, "sign_up_variants must be a hash of names to i18n keys" unless value.is_a?(Hash)

      compiled = value.each_with_object({ variants: {}, index: {} }) do |(name, copy), memo|
        store_sign_up_variant(memo, name, copy)
      end
      compiled[:variants].freeze
      compiled[:index].freeze
      compiled
    end

    def store_sign_up_variant(memo, name, copy)
      key = variant_config_name(name)
      title, subtitle = variant_copy_keys(copy)
      entry = { title: title }
      entry[:subtitle] = subtitle if subtitle
      memo[:variants][key.to_sym] = entry.freeze
      memo[:index][key] = entry
    end

    def empty_sign_up_variants
      { variants: {}.freeze, index: {}.freeze }
    end

    def assign_sign_up_variants(compiled)
      @sign_up_variants = compiled.fetch(:variants)
      @sign_up_variant_index = compiled.fetch(:index)
    end

    def variant_config_name(name)
      text = case name
             when Symbol then name.name
             when String then name
             else raise ArgumentError, "sign_up variant name must be a lowercase word"
             end
      return text if VARIANT_NAME.match?(text)

      raise ArgumentError, "sign_up variant name must be a lowercase word"
    end

    def variant_copy_keys(copy)
      data = variant_copy_data(copy)
      unknown = data.keys - %w[title subtitle]
      raise ArgumentError, "sign_up variant only accepts title and subtitle" if unknown.any?

      [sign_up_i18n_key(data["title"], required: true), sign_up_i18n_key(data["subtitle"], required: false)]
    end

    def variant_copy_data(copy)
      raise ArgumentError, "sign_up variant needs a title i18n key" unless copy.is_a?(Hash)

      copy.each_with_object({}) { |(key, item), memo| memo[variant_copy_name(key)] = item }
    end

    def variant_copy_name(key)
      return key.name if key.is_a?(Symbol)
      return key if key.is_a?(String)

      raise ArgumentError, "sign_up variant only accepts title and subtitle"
    end

    def sign_up_i18n_key(value, required:)
      text = value.to_s.strip
      return if text.empty? && !required
      raise ArgumentError, "sign_up variant needs a title i18n key" if text.empty?
      return text if text.length <= I18N_KEY_MAX && I18N_KEY.match?(text)

      raise ArgumentError, "sign_up variant copy must be an i18n key"
    end

    def variant_request_text(raw)
      case raw
      when Symbol then raw.name
      when String then raw
      end
    end

    def translated_sign_up_key(key)
      return if key.blank?

      text = I18n.t(key, default: nil)
      return unless text.is_a?(String)

      stripped = text.strip
      return if stripped.empty? || stripped == key || stripped.include?("translation missing")

      stripped
    rescue I18n::MissingTranslationData
      nil
    end

    def default_sign_up_heading
      { title: I18n.t("recording_studio_user.auth.sign_up"), subtitle: nil }
    end

    def normalized_popup_origins(value)
      Array(value).map { |origin| origin.to_s.strip }.reject(&:empty?).uniq
    end

    def popup_origins_valid?(origins)
      origins.all? { |origin| origin.match?(POPUP_ORIGIN) }
    end
  end
end
