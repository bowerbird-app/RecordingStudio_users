# frozen_string_literal: true

module RecordingStudioUser
  # Opaque signup context. Callers pass a Hash. The session stores strings.
  # The registration event receives symbol keys and the original scalars.
  module SignupSource
    SESSION_KEY = "recording_studio_user_signup_source"
    MAX_KEYS = 8
    MAX_STRING = 255
    KEY_PATTERN = /\A[a-z_][a-z0-9_]{0,39}\z/
    READERS = {
      "s" => ->(rest) { rest },
      "y" => lambda(&:to_sym),
      "i" => ->(rest) { rest.match?(/\A-?\d+\z/) ? Integer(rest, 10) : :bad },
      "t" => ->(rest) { rest.empty? || :bad },
      "f" => ->(rest) { rest.empty? ? false : :bad },
      "n" => ->(rest) { rest.empty? ? nil : :bad }
    }.freeze

    module_function

    def remember_request!(request, source)
      raise ArgumentError, "request is required" if request.nil?

      remember!(request.session, source)
    end

    def remember!(session, source)
      normalized = normalize!(source)
      raise ArgumentError, "session is required" if session.nil?

      session[SESSION_KEY] = encode(normalized)
      normalized
    end

    def read(session)
      return if session.nil?

      decode(session[SESSION_KEY])
    end

    def take!(session)
      value = read(session)
      clear!(session)
      value
    end

    def clear!(session)
      session&.delete(SESSION_KEY)
    end

    def normalize!(source)
      raise ArgumentError, "signup source must be a Hash" unless source.is_a?(Hash)
      raise ArgumentError, "signup source has too many keys" if source.size > MAX_KEYS

      normalized = {}
      source.each do |key, value|
        symbol = normalize_key!(key)
        raise ArgumentError, "signup source key is duplicated" if normalized.key?(symbol)

        normalized[symbol] = normalize_value!(value)
      end
      normalized
    end

    def normalize_key!(key)
      text = key.is_a?(Symbol) || key.is_a?(String) ? key.to_s : nil
      raise ArgumentError, "signup source key must be a symbol or string" if text.nil?
      raise ArgumentError, "signup source key is invalid" unless KEY_PATTERN.match?(text)

      text.to_sym
    end

    def normalize_value!(value)
      raise ArgumentError, "signup source string is too long" if value.is_a?(String) && value.length > MAX_STRING
      return value if allowed_scalar?(value)

      raise ArgumentError, "signup source value must be a scalar"
    end

    def allowed_scalar?(value)
      value.is_a?(String) || [Symbol, Integer, TrueClass, FalseClass, NilClass].any? { |type| value.is_a?(type) }
    end

    def encode(normalized)
      normalized.each_with_object({}) do |(key, value), stored|
        stored[key.to_s] = encode_value(value)
      end
    end

    def encode_value(value)
      return "n:" if value.nil?
      return "t:" if value == true
      return "f:" if value == false
      return "s:#{value.to_str}" if value.is_a?(String)
      return "y:#{value}" if value.is_a?(Symbol)
      return "i:#{value}" if value.is_a?(Integer)

      "n:"
    end

    def decode(raw)
      return unless raw.is_a?(Hash) && raw.size <= MAX_KEYS

      decoded = {}
      decoded if raw.all? { |key, value| store_decoded?(decoded, key, value) }
    end

    def store_decoded?(decoded, key, value)
      symbol = decode_key(key)
      scalar = decode_scalar(value)
      return false unless symbol && scalar != :bad && !decoded.key?(symbol)

      decoded[symbol] = scalar
      true
    end

    def decode_key(key)
      key.to_sym if key.is_a?(String) && KEY_PATTERN.match?(key)
    end

    def decode_scalar(encoded)
      return :bad unless encoded.is_a?(String)

      type, rest = encoded.split(":", 2)
      return :bad if rest.nil? || !READERS.key?(type)

      READERS[type].call(rest)
    end
  end
end
