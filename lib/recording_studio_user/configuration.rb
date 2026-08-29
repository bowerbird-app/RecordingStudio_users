# frozen_string_literal: true

module RecordingStudioUser
  DEFAULT_LOGIN_TITLE = "Welcome back"

  class Configuration
    PROTECTED_PROFILE_ATTRIBUTES = %w[
      id email password password_confirmation encrypted_password reset_password_token
      reset_password_sent_at remember_created_at admin role roles root_id root_recording_id
      recording_id recordable_id recordable_type membership memberships
    ].freeze

    attr_accessor :user_class_name, :layout
    attr_reader :mount_path, :profile_route_path, :admin_route_path, :additional_profile_attributes,
                :require_password_confirmation, :login_title, :omniauth_providers, :omniauth_create_account

    def initialize
      @user_class_name = "User"
      @mount_path = "/recording_studio_users"
      @profile_route_path = "profile"
      @admin_route_path = "admin"
      @layout = "application"
      @additional_profile_attributes = []
      @require_password_confirmation = true
      @login_title = DEFAULT_LOGIN_TITLE
      @omniauth_providers = {}
      @omniauth_create_account = true
    end

    def require_password_confirmation=(value)
      @require_password_confirmation = ActiveModel::Type::Boolean.new.cast(value)
    end

    def require_password_confirmation?
      require_password_confirmation
    end

    def login_title=(value)
      @login_title = value.to_s.strip.presence || DEFAULT_LOGIN_TITLE
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
    end

    private

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
