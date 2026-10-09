# frozen_string_literal: true

require_relative "api/access"
require "recording_studio_metrics"

module RecordingStudioUser
  module Metrics
    RESOURCE = :users
    API = :operations
    CONFIRMABLE_COLUMN = "confirmed_at"
    EXPOSE = { api: [API] }.freeze

    module_function

    def register!
      user_class = RecordingStudioUser.config.user_class
      RecordingStudioMetrics.register(
        RESOURCE,
        model: user_class,
        blast_radius: :site,
        api_authorize: ->(context) { RecordingStudioUser::Api::Access.can_view?(context) }
      ) do
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

    def confirmable_column?(user_class)
      return false unless user_class.respond_to?(:column_names)
      return false if user_class.respond_to?(:table_exists?) && !user_class.table_exists?

      user_class.column_names.include?(CONFIRMABLE_COLUMN)
    rescue ActiveRecord::ActiveRecordError
      false
    end
  end
end
