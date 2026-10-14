# frozen_string_literal: true

require_relative "api/access"
require "recording_studio_metrics"

module RecordingStudioUser
  module Metrics
    RESOURCE = :users
    OTP_RESOURCE = :otp_challenges
    API = :operations
    CONFIRMABLE_COLUMN = "confirmed_at"
    EXPOSE = { api: [API] }.freeze

    module_function

    def register!
      register_users!
      register_otp_challenges!
    end

    def register_users!
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

    # OTP challenges share the users AdminRoot :view check and site blast radius.
    def register_otp_challenges!
      RecordingStudioMetrics.register(
        OTP_RESOURCE,
        model: RecordingStudioUser::OtpChallenge,
        blast_radius: :site,
        api_authorize: ->(context) { RecordingStudioUser::Api::Access.can_view?(context) }
      ) do
        RecordingStudioUser::Metrics.define_otp_failures(self)
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
                 unit: "count",
                 expose: EXPOSE,
                 &confirmation_calculator
    end

    # A failed challenge is one VerifyOtp locked: OtpChallenge#increment_attempts!
    # revokes it once attempts_count reaches otp_max_attempts. Each challenge
    # counts once, in the bucket of its revoked_at. Challenges revoked because a
    # new code was issued (IssueOtp) are revoked below the limit and are not
    # counted. Expired-unused challenges and single wrong-code attempts carry no
    # failure timestamp, so they are not counted.
    def define_otp_failures(dsl)
      dsl.timeseries :failed_over_time,
                     title: "Failed OTP challenges over time",
                     description: "OTP challenges locked after otp_max_attempts wrong codes, " \
                                  "bucketed by when they were locked (revoked_at).",
                     field: :revoked_at,
                     unit: "count",
                     group_by: %i[purpose],
                     scope: otp_failed_scope,
                     expose: EXPOSE
    end

    def otp_failed_scope
      lambda do |relation|
        relation.where.not(revoked_at: nil)
                .where(attempts_count: RecordingStudioUser.config.otp_max_attempts..)
      end
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
