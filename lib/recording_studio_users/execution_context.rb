# frozen_string_literal: true

module RecordingStudioUsers
  module ExecutionContext
    KEY = :recording_studio_users_execution_context

    module_function

    def with(kind, value)
      state = ActiveSupport::IsolatedExecutionState[KEY] ||= {}
      previous = state[kind]
      state[kind] = value
      yield
    ensure
      state[kind] = previous
      ActiveSupport::IsolatedExecutionState.delete(KEY) if state.values.compact.empty?
    end

    def fetch(kind)
      ActiveSupport::IsolatedExecutionState[KEY]&.fetch(kind, nil)
    end
  end
end
