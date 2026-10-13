# frozen_string_literal: true

module RecordingStudioUser
  # Runs host-configured after_registration hooks after a successful sign-up.
  # Invoked from RegistrationCompleted alongside the unchanged instrumentation event.
  module AfterRegistration
    module_function

    def run!(user_id:, method:)
      hooks = RecordingStudioUser.config.after_registration_hooks
      return if hooks.empty?

      user = resolve_user(user_id)
      return if user.nil?

      method = method.to_sym
      hooks.each do |hook|
        invoke_hook(hook, user: user, method: method)
      end
    end

    def resolve_user(user_id)
      return if user_id.blank?

      RecordingStudioUser.config.user_class.find_by(id: user_id)
    rescue ArgumentError, NameError
      nil
    end

    def invoke_hook(hook, user:, method:)
      handler = resolve_handler(hook)
      unless handler.respond_to?(:call)
        raise ArgumentError, "after_registration hook #{hook.inspect} does not respond to call"
      end

      handler.call(user: user, method: method)
    rescue StandardError => e
      report_failure(e)
    end

    def resolve_handler(hook)
      return hook if hook.respond_to?(:call)
      return hook.constantize if hook.is_a?(String)

      raise ArgumentError, "Unsupported after_registration hook #{hook.inspect}"
    end

    def report_failure(error)
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.error(
          "[RecordingStudioUser] after_registration hook failed: " \
          "#{error.class}: #{error.message}"
        )
      end
      return unless defined?(Rails) && Rails.respond_to?(:error) && Rails.error

      Rails.error.report(error, handled: true)
    end
  end
end
