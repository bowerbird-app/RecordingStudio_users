# frozen_string_literal: true

module RecordingStudioUser
  class CodeSignInCopy
    KEY = /\A[a-z0-9_]+(?:\.[a-z0-9_]+){0,8}\z/
    KEY_MAX = 80
    PARAM_KEY = /\A[a-z][a-z0-9_]{0,23}\z/
    PARAMS_MAX = 4
    VALUE_MAX = 80
    RESERVED = %w[default raise scope fallback separator deep_interpolation].freeze

    class << self
      def pack(copy)
        return if copy.blank?

        key, params = parts(copy)
        raise ArgumentError, "title and reason must be i18n keys" unless valid?(key, params)

        packed = { "key" => key }
        packed["params"] = params if params.present?
        packed
      end

      def pair(title, reason)
        unpacked = [unpack(title), unpack(reason)]
        unpacked unless unpacked.any?(:invalid)
      end

      def text(packed, fallback:)
        return fallback if packed.blank?

        translated = I18n.t(packed["key"], **interpolate(packed), default: fallback)
        readable?(translated, packed["key"]) ? translated : fallback
      rescue I18n::MissingInterpolationArgument, I18n::InvalidPluralizationData
        fallback
      end

      private

      def parts(copy)
        return [copy.to_s, {}] if copy.is_a?(String)
        return [nil, nil] unless copy.is_a?(Hash)

        data = copy.stringify_keys
        [data.delete("key").to_s, data]
      end

      def unpack(copy)
        return if copy.blank?
        return :invalid unless copy.is_a?(Hash)

        key = copy["key"].to_s
        params = copy["params"] || {}
        return :invalid unless valid?(key, params)

        packed = { "key" => key }
        packed["params"] = params if params.present?
        packed
      end

      def valid?(key, params)
        return false unless key.is_a?(String) && key.length <= KEY_MAX && KEY.match?(key)
        return false unless params.is_a?(Hash) && params.size <= PARAMS_MAX

        params.all? { |name, value| param_ok?(name, value) }
      end

      def param_ok?(name, value)
        name.to_s.match?(PARAM_KEY) && RESERVED.exclude?(name.to_s) && scalar?(value)
      end

      def scalar?(value)
        (value.is_a?(String) || value.is_a?(Integer)) && value.to_s.length <= VALUE_MAX
      end

      def interpolate(packed)
        packed.fetch("params", {}).symbolize_keys
      end

      def readable?(translated, key)
        translated.is_a?(String) && translated.present? && translated != key &&
          translated.exclude?("translation missing")
      end
    end
  end
end
