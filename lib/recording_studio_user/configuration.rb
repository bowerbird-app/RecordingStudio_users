# frozen_string_literal: true

module RecordingStudioUser
  class Configuration
    attr_accessor :user_model, :profile_path, :profile_scope, :default_layout,
                  :additional_permitted_profile_attributes, :admin_registration_hook

    def initialize
      @user_model = "RecordingStudioUser::User"
      @profile_path = "profile"
      @profile_scope = nil
      @default_layout = "application"
      @additional_permitted_profile_attributes = []
      @admin_registration_hook = -> { RecordingStudioUser.register_admin! }
    end

    def to_h
      {
        user_model: user_model,
        profile_path: profile_path,
        profile_scope: profile_scope,
        default_layout: default_layout,
        additional_permitted_profile_attributes: additional_permitted_profile_attributes
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

    def permitted_profile_attributes
      %i[first_name last_name time_zone] + Array(additional_permitted_profile_attributes).map(&:to_sym)
    end

    def register_admin!
      admin_registration_hook&.call
    end
  end
end
