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
    EXPOSE = { api: [API] }.freeze

    module_function

    def register!
      return unless ready?

      RecordingStudioMetrics.register(RESOURCE, **resource_options, &catalog)
    rescue ArgumentError
      # Host user class may not be loadable during early boot.
    end

    def ready?
      metrics_available? && !(already_registered? && !reloading?)
    end

    def resource_options
      {
        model: RecordingStudioUser.config.user_class,
        blast_radius: :site,
        api_authorize: ->(context) { RecordingStudioUser::Api::Access.can_view?(context) }
      }
    end

    def catalog
      user_class = RecordingStudioUser.config.user_class
      proc do
        RecordingStudioUser::Metrics.define_core(self)
        RecordingStudioUser::Metrics.define_confirmation(self, user_class)
      end
    end

    def define_core(dsl)
      dsl.count :total, title: "Total users", expose: EXPOSE
      dsl.timeseries :signups, title: "Signups over time", field: :created_at, expose: EXPOSE
      dsl.timeseries :total_over_time,
                     title: "Total users over time",
                     field: :created_at,
                     semantics: "population_at_end_of_period",
                     expose: EXPOSE
      dsl.breakdown :by_method, title: "Signups by method", field: :registered_with, expose: EXPOSE
    end

    def define_confirmation(dsl, user_class)
      return unless confirmable_column?(user_class)

      dsl.custom :confirmation,
                 result_type: :breakdown,
                 title: "Confirmed vs unconfirmed",
                 expose: EXPOSE,
                 &confirmation_calculator
    end

    def confirmation_calculator
      lambda do |relation, _context|
        [
          { key: "confirmed", value: relation.where.not(confirmed_at: nil).distinct.count },
          { key: "unconfirmed", value: relation.where(confirmed_at: nil).distinct.count }
        ]
      end
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
