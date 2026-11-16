# frozen_string_literal: true

module RecordingStudioUser
  # Holds the code-email job while the signup transaction is open, then runs it
  # after that transaction returns. A rollback never runs the held job.
  module OtpDeliveryDeferral
    HOLDING = :recording_studio_user_holding_otp_deliveries
    HELD = :recording_studio_user_held_otp_deliveries
    PENDING = :recording_studio_user_pending_otp_deliveries

    module Job
      def perform_later(*arguments, **keyword_arguments)
        return if defer_job(:perform_later, arguments, keyword_arguments)

        super
      end

      def perform_now(*arguments, **keyword_arguments)
        return if defer_job(:perform_now, arguments, keyword_arguments)

        super
      end

      private

      def defer_job(method_name, arguments, keyword_arguments)
        OtpDeliveryDeferral.remember(method_name, self, arguments, keyword_arguments)
      end
    end

    class << self
      def install!
        return unless defined?(RecordingStudioNotifications::DeliveryJob)

        singleton = RecordingStudioNotifications::DeliveryJob.singleton_class
        return if singleton.ancestors.include?(Job)

        singleton.prepend(Job)
      end

      def holding?
        Thread.current[HOLDING] == true
      end

      def remember(method_name, job_class, arguments, keyword_arguments)
        return unless holding?

        Thread.current[HELD] << [job_class, method_name, arguments, keyword_arguments]
      end

      def defer
        install!
        with_held_jobs do |held|
          result = yield
          Thread.current[PENDING] = result ? held : nil
          result
        end
      end

      def with_held_jobs
        previous_holding = Thread.current[HOLDING]
        previous_held = Thread.current[HELD]
        held = []
        Thread.current[HOLDING] = true
        Thread.current[HELD] = held
        yield held
      ensure
        Thread.current[HOLDING] = previous_holding
        Thread.current[HELD] = previous_held
      end

      def flush!
        jobs = Thread.current[PENDING]
        Thread.current[PENDING] = nil
        Array(jobs).each do |job_class, method_name, arguments, keyword_arguments|
          job_class.public_send(method_name, *arguments, **keyword_arguments)
        end
      end

      def discard!
        Thread.current[PENDING] = nil
        Thread.current[HOLDING] = nil
        Thread.current[HELD] = nil
      end
    end
  end
end
