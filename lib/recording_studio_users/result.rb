# frozen_string_literal: true

module RecordingStudioUsers
  Result = Data.define(:value, :error) do
    def self.success(value = nil)
      new(value: value, error: nil)
    end

    def self.failure(error)
      new(value: nil, error: error.to_s)
    end

    def success?
      error.nil?
    end

    def failure?
      !success?
    end
  end
end
