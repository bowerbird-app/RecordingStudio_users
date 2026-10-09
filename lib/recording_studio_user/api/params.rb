# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Params
      PROFILE_KEYS = %i[first_name last_name time_zone additional_profile_attributes].freeze
      USER_KEYS = %i[email password password_confirmation].freeze

      module_function

      def request_hash(context)
        raw = context&.params
        return {} if raw.blank?

        hash = hash_from(raw)
        hash.respond_to?(:deep_symbolize_keys) ? hash.deep_symbolize_keys : hash
      end

      def hash_from(raw)
        return raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
        return raw.to_h if raw.respond_to?(:to_h)

        {}
      end

      def create_attributes(context)
        slice_writable(request_hash(context), USER_KEYS + PROFILE_KEYS)
      end

      def update_attributes(context)
        hash = request_hash(context)
        reject_email_update!(hash)
        slice_writable(hash, PROFILE_KEYS)
      end

      def reject_email_update!(hash)
        return unless hash.key?(:email)

        Errors.invalid_input!("email cannot be changed through the operations users API")
      end

      def page(context)
        request_hash(context)[:page]
      end

      def per_page(context)
        request_hash(context)[:per_page]
      end

      def record_id(context)
        hash = request_hash(context)
        hash[:id].presence || hash[:user_id].presence
      end

      def slice_writable(hash, keys)
        extras = hash[:additional_profile_attributes]
        extras = extras.to_h if extras.respond_to?(:to_h)
        allowlisted = RecordingStudioUser.config.additional_profile_attributes.map(&:to_sym)
        top_level_extras = hash.slice(*allowlisted)
        merged_extras = (extras || {}).symbolize_keys.merge(top_level_extras)
        hash.slice(*keys).merge(additional_profile_attributes: merged_extras)
      end
    end
  end
end
