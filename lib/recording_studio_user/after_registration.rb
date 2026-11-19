# frozen_string_literal: true

module RecordingStudioUser
  # Runs host-configured after_registration hooks after a successful sign-up.
  # A hook that declares source: receives it when a signup source was passed.
  # A hook that only accepts user: and method: is called the same way as before.
  module AfterRegistration
    module_function

    def run!(user_id:, method:, source: nil)
      hooks = RecordingStudioUser.config.after_registration_hooks
      return if hooks.empty?

      user = resolve_user(user_id)
      return if user.nil?

      method = method.to_sym
      hooks.each do |hook|
        invoke_hook(hook, user: user, method: method, source: source)
      end
    end

    def resolve_user(user_id)
      return if user_id.blank?

      RecordingStudioUser.config.user_class.find_by(id: user_id)
    rescue ArgumentError, NameError
      nil
    end

    def invoke_hook(hook, user:, method:, source:)
      handler = resolve_handler(hook)
      unless handler.respond_to?(:call)
        raise ArgumentError, "after_registration hook #{hook.inspect} does not respond to call"
      end

      handler.call(**hook_keywords(handler, user: user, method: method, source: source))
    rescue StandardError => e
      report_failure(e)
    end

    def hook_keywords(handler, user:, method:, source:)
      keywords = { user: user, method: method }
      keywords[:source] = source if !source.nil? && accepts_keyword?(handler, :source)
      keywords
    end

    def accepts_keyword?(handler, name)
      call_parameters(handler).any? do |kind, key|
        kind == :keyrest || (key == name && %i[key keyreq].include?(kind))
      end
    end

    def call_parameters(handler)
      return handler.parameters if handler.is_a?(Proc)

      handler.method(:call).parameters
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
