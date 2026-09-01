# frozen_string_literal: true

module RecordingStudioUser
  # Normalizes the mount and route paths a host may configure.
  module RoutePath
    SAFE_PATH = %r{\A[a-zA-Z0-9][a-zA-Z0-9_/-]*\z}

    module_function

    def mount(value)
      path = value.to_s.strip
      raise ArgumentError, "Mount path cannot be empty" if path.blank?

      normalized = "/#{path.delete_prefix('/').delete_suffix('/')}"
      validate!(normalized.delete_prefix("/"))
      normalized
    end

    def relative(value)
      path = value.to_s.strip.delete_prefix("/").delete_suffix("/")
      raise ArgumentError, "Route path cannot be empty" if path.blank?

      validate!(path)
      path
    end

    def validate!(path)
      return if path.match?(SAFE_PATH) && !path.include?("//")

      raise ArgumentError, "Route path must be a non-empty relative path"
    end
  end
end
