# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Metrics
      module_function

      def register!
        return unless actor_metrics_supported?

        RecordingStudioApi.register_actor_metrics(
          RecordingStudioUser.config.user_class.name,
          api: USERS_API,
          resource: RecordingStudioUser::Metrics::RESOURCE,
          authorize: Access.method(:authorize_view!)
        )
      end

      def actor_metrics_supported?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:register_actor_metrics)
      end
      private_class_method :actor_metrics_supported?
    end
  end
end
