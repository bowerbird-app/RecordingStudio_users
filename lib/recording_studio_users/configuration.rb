# frozen_string_literal: true

module RecordingStudioUsers
  class Configuration
    PROFILE_FIELDS = %i[display_name biography locale time_zone].freeze
    DEFAULT_AVATAR_TYPES = ["image/jpeg", "image/png", "image/webp", "image/gif"].freeze
    DEFAULT_VARIANTS = { small: :square_small, medium: :square_med, large: :square_large }.freeze
    DEFAULT_DIMENSIONS = { small: 32, medium: 40, large: 64 }.freeze
    SUPPORTED_DEVISE_MODULES = %i[
      database_authenticatable registerable recoverable rememberable validatable confirmable lockable
      trackable timeoutable omniauthable
    ].freeze

    attr_accessor :user_class_name, :current_actor, :current_impersonator, :provisioning_actor,
                  :layout, :public_registration, :devise_modules, :profile_fields,
                  :identity_visibility_policy, :email_visibility_policy, :profile_visibility_policy,
                  :profile_edit_policy, :stored_avatar_delivery_policy, :user_label, :search_scope,
                  :search_authorizer, :picker_limit, :avatar_content_types, :avatar_max_byte_size,
                  :avatar_variant_mapping, :avatar_dimensions, :external_avatar_resolver,
                  :admin_enabled, :auto_provision, :event_actions, :instrumenter

    def initialize
      @user_class_name = "User"
      @current_actor = lambda { |controller: nil, **|
        controller.respond_to?(:current_user, true) ? controller.send(:current_user) : nil
      }
      @current_impersonator = lambda do |controller: nil, **|
        controller.respond_to?(:current_impersonator, true) ? controller.send(:current_impersonator) : nil
      end
      @provisioning_actor = nil
      @layout = "application"
      @public_registration = true
      @devise_modules = %i[database_authenticatable registerable recoverable rememberable validatable]
      @profile_fields = PROFILE_FIELDS.dup
      @identity_visibility_policy = ->(user:, actor: nil, **) { actor.present? && user == actor }
      @email_visibility_policy = ->(user:, actor: nil, **) { actor.present? && user == actor }
      @profile_visibility_policy = ->(user:, actor: nil, **) { actor.present? && user == actor }
      @profile_edit_policy = ->(user:, actor:, **) { actor.present? && user == actor }
      @stored_avatar_delivery_policy = ->(user:, actor: nil, **) { actor.present? && user == actor }
      @user_label = ->(user:, **) { user.respond_to?(:name) ? user.name : nil }
      @search_scope = nil
      @search_authorizer = ->(**) { false }
      @picker_limit = 20
      @avatar_content_types = DEFAULT_AVATAR_TYPES.dup
      @avatar_max_byte_size = 5.megabytes
      @avatar_variant_mapping = DEFAULT_VARIANTS.dup
      @avatar_dimensions = DEFAULT_DIMENSIONS.dup
      @external_avatar_resolver = nil
      @admin_enabled = true
      @auto_provision = true
      @event_actions = %w[user_signed_in password_changed].freeze
      @instrumenter = nil
    end

    def to_h
      {
        user_class_name: user_class_name,
        current_actor: callable_metadata(current_actor),
        current_impersonator: callable_metadata(current_impersonator),
        provisioning_actor: callable_metadata(provisioning_actor),
        layout: layout,
        public_registration: public_registration,
        devise_modules: devise_modules,
        profile_fields: profile_fields,
        identity_visibility_policy: callable_metadata(identity_visibility_policy),
        email_visibility_policy: callable_metadata(email_visibility_policy),
        profile_visibility_policy: callable_metadata(profile_visibility_policy),
        profile_edit_policy: callable_metadata(profile_edit_policy),
        stored_avatar_delivery_policy: callable_metadata(stored_avatar_delivery_policy),
        user_label: callable_metadata(user_label),
        search_scope: callable_metadata(search_scope),
        search_authorizer: callable_metadata(search_authorizer),
        picker_limit: picker_limit,
        avatar_content_types: avatar_content_types,
        avatar_max_byte_size: avatar_max_byte_size,
        avatar_variant_mapping: avatar_variant_mapping,
        avatar_dimensions: avatar_dimensions,
        external_avatar_resolver: callable_metadata(external_avatar_resolver),
        admin_enabled: admin_enabled,
        auto_provision: auto_provision,
        event_actions: event_actions,
        instrumenter: callable_metadata(instrumenter)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end

    def user_class
      user_class_name.to_s.safe_constantize ||
        raise(ConfigurationError, "Configured User class #{user_class_name.inspect} is not available")
    end

    def validate!
      self.profile_fields = Array(profile_fields).map(&:to_sym)
      unknown_fields = profile_fields - PROFILE_FIELDS
      raise ConfigurationError, "Unsupported Profile fields: #{unknown_fields.join(', ')}" if unknown_fields.any?

      self.avatar_variant_mapping = avatar_variant_mapping.to_h.symbolize_keys.transform_values(&:to_sym)
      unknown_sizes = avatar_variant_mapping.keys - DEFAULT_VARIANTS.keys
      raise ConfigurationError, "Unsupported avatar sizes: #{unknown_sizes.join(', ')}" if unknown_sizes.any?

      missing_sizes = DEFAULT_VARIANTS.keys - avatar_variant_mapping.keys
      raise ConfigurationError, "Missing avatar sizes: #{missing_sizes.join(', ')}" if missing_sizes.any?

      untrusted_variants = avatar_variant_mapping.values - DEFAULT_VARIANTS.values
      if untrusted_variants.any?
        raise ConfigurationError,
              "Unsupported avatar variants: #{untrusted_variants.join(', ')}"
      end

      self.avatar_dimensions = avatar_dimensions.to_h.symbolize_keys
      missing_dimensions = DEFAULT_DIMENSIONS.keys - avatar_dimensions.keys
      raise ConfigurationError, "Missing avatar dimensions: #{missing_dimensions.join(', ')}" if missing_dimensions.any?
      unless avatar_dimensions.values.all? { |dimension| dimension.to_i.positive? }
        raise ConfigurationError, "Avatar dimensions must be positive"
      end

      self.avatar_content_types = Array(avatar_content_types).map(&:to_s)
      unless avatar_content_types.any? && avatar_content_types.all? { |type| type.start_with?("image/") }
        raise ConfigurationError, "Avatar content types must contain only image types"
      end

      self.devise_modules = Array(devise_modules).map(&:to_sym)
      unsupported_modules = devise_modules - SUPPORTED_DEVISE_MODULES
      if unsupported_modules.any?
        raise ConfigurationError,
              "Unsupported Devise modules: #{unsupported_modules.join(', ')}"
      end

      self.picker_limit = Integer(picker_limit)
      raise ConfigurationError, "picker_limit must be between 1 and 100" unless picker_limit.between?(1, 100)
      raise ConfigurationError, "avatar_max_byte_size must be positive" unless avatar_max_byte_size.to_i.positive?

      self
    rescue ArgumentError, TypeError => e
      raise ConfigurationError, e.message
    end

    private

    def callable_metadata(value)
      value.respond_to?(:call) ? :configured : nil
    end
  end
end
