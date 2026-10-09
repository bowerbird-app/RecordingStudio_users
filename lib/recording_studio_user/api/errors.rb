# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Errors
      module_function

      def not_found!(message = "User was not found")
        raise RecordingStudioApi::NotFoundError, message
      end

      def invalid_input!(message, details: [])
        raise RecordingStudioApi::InvalidActionInputError.new(message, details: details)
      end

      def from_record_invalid(error)
        details = error.record.errors.map do |entry|
          {
            attribute: entry.attribute,
            message: entry.message,
            full_message: entry.full_message,
            type: entry.type
          }
        end
        invalid_input!(error.message, details: details)
      end
    end
  end
end
