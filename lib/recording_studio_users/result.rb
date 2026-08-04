# frozen_string_literal: true

module RecordingStudioUsers
  Result = Data.define(:success?, :value, :error, :errors) do
    def self.success(value = nil)
      new(true, value, nil, [].freeze)
    end

    def self.failure(error, errors: [])
      message = error.is_a?(Exception) ? error.message : error.to_s
      new(false, nil, message, Array(errors).compact.freeze)
    end

    def failure? = !success?

    def self.from_dependency(result)
      return success(result) unless result.respond_to?(:success?)
      return success(result.value) if result.success?

      failure(result.error, errors: result.respond_to?(:errors) ? result.errors : [])
    end
  end
end
