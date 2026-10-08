# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Errors
      module_function

      def not_found!(message = "User was not found")
        raise not_found_error, message
      end

      def invalid_input!(message, details: [])
        error_class = if defined?(RecordingStudioApi::InvalidActionInputError)
                        RecordingStudioApi::InvalidActionInputError
                      else
                        ArgumentError
                      end
        if error_class == ArgumentError
          raise error_class, message
        else
          raise error_class.new(message, details: details)
        end
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

      def not_found_error
        if defined?(RecordingStudioApi::NotFoundError)
          RecordingStudioApi::NotFoundError
        else
          KeyError
        end
      end
    end
  end
end
