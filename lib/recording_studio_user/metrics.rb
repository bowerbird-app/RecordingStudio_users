# frozen_string_literal: true

require_relative "api/access"

begin
  require "recording_studio_metrics"
rescue LoadError
  # Hosts and the gem suite can boot without Metrics loaded yet.
end

module RecordingStudioUser
  module Metrics
    RESOURCE = :users
    API = :operations
    CONFIRMABLE_COLUMN = "confirmed_at"

    module_function

    def register!
      return unless metrics_available?

      user_class = RecordingStudioUser.config.user_class
      return if already_registered? && !reloading?

      RecordingStudioMetrics.register(
        RESOURCE,
        model: user_class,
        blast_radius: :site,
        api_authorize: ->(context) { RecordingStudioUser::Api::Access.can_view?(context) }
      ) do
        count :total, title: "Total users", expose: { api: [API] }

        timeseries :signups,
                   title: "Signups over time",
                   field: :created_at,
                   expose: { api: [API] }

        timeseries :total_over_time,
                   title: "Total users over time",
                   field: :created_at,
                   semantics: "population_at_end_of_period",
                   expose: { api: [API] }

        breakdown :by_method,
                  title: "Signups by method",
                  field: :registered_with,
                  expose: { api: [API] }

        if RecordingStudioUser::Metrics.confirmable_column?(user_class)
          custom :confirmation,
                 result_type: :breakdown,
                 title: "Confirmed vs unconfirmed",
                 expose: { api: [API] } do |relation, _context|
            [
              { key: "confirmed", value: relation.where.not(confirmed_at: nil).distinct.count },
              { key: "unconfirmed", value: relation.where(confirmed_at: nil).distinct.count }
            ]
          end
        end
      end
    rescue ArgumentError
      # Host user class may not be loadable during early boot.
    end

    def metrics_available?
      defined?(RecordingStudioMetrics) && RecordingStudioMetrics.respond_to?(:register)
    end

    def already_registered?
      RecordingStudioMetrics.for_resource(RESOURCE).any?
    end

    def reloading?
      defined?(Rails) &&
        Rails.respond_to?(:application) &&
        Rails.application &&
        Rails.application.config.respond_to?(:cache_classes) &&
        Rails.application.config.cache_classes == false
    end

    def confirmable_column?(user_class)
      return false unless user_class.respond_to?(:column_names)
      return false if user_class.respond_to?(:table_exists?) && !user_class.table_exists?

      user_class.column_names.include?(CONFIRMABLE_COLUMN)
    rescue StandardError
      false
    end
  end
end
