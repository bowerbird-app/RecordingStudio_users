# frozen_string_literal: true

module RecordingStudioUser
  module Services
    # Per-account sign-in lockout. Code failures are the sum of
    # +otp_challenges.attempts_count+ for that user, every purpose, created
    # inside the window and after the latest consumed challenge. Password
    # failures are rows in +recording_studio_user_password_failures+. A
    # successful password sign-in deletes those rows. An expired lock is also
    # a floor, so the same failures do not start another lock when the pause
    # ends. Code and password locks do not block each other.
    class AccountLockout
      def self.locked?(user, kind)
        active_lock(user, kind).present?
      end

      # The attempt is already stored. Returns a lock that still needs its one email.
      def self.record_otp_failure!(user)
        remember_failure(user, :otp) { otp_failure_count(user) }
      end

      def self.record_password_failure!(user)
        lock = remember_failure(user, :password) do
          PasswordFailure.create!(user: user)
          password_failure_count(user)
        end
        deliver!(lock)
        lock
      end

      def self.reset_password!(user)
        return if user.blank?

        PasswordFailure.where(user_id: user.id).delete_all
        SignInLock.where(user_id: user.id, kind: "password").delete_all
      end

      def self.deliver!(lock)
        return if lock.blank?

        lock.with_lock do
          next if lock.notified_at.present?

          notify!(lock)
          lock.update!(notified_at: Time.current)
        end
      rescue StandardError => e
        Rails.logger.error("RecordingStudioUser sign-in lock email failed: #{e.class}")
      end

      def self.otp_failure_count(user)
        scope = OtpChallenge.where(user_id: user.id).where(created_at: (Time.current - limits(:otp)[:window])..)
        otp_floors(user).each { |time| scope = scope.where("created_at > ?", time) }
        scope.sum(:attempts_count)
      end

      def self.password_failure_count(user)
        PasswordFailure.count_for(
          user,
          window_start: Time.current - limits(:password)[:window],
          after: expired_lock_end(user, :password)
        )
      end

      def self.active_lock(user, kind)
        return if user.blank?

        lock = SignInLock.latest_for(user, kind)
        return if lock.nil? || expired?(lock, kind)

        lock
      end

      def self.remember_failure(user, kind)
        return if user.blank?

        user.with_lock do
          active = active_lock(user, kind)
          next active if active && active.notified_at.blank?
          next if active
          next if yield < limits(kind)[:max]

          SignInLock.create!(user: user, kind: kind.to_s, locked_at: Time.current)
        end
      end
      private_class_method :remember_failure

      def self.notify!(lock)
        return unless defined?(RecordingStudioNotifications)

        RecordingStudioNotifications.notify(
          notification_type: :sign_in_lockout,
          recipient: lock.user,
          title: I18n.t("recording_studio_user.auth.lockout.#{lock.kind}.title"),
          body: I18n.t("recording_studio_user.auth.lockout.#{lock.kind}.body"),
          channels: [:email],
          metadata: { "kind" => lock.kind },
          idempotency_key: "sign-in-lock/#{lock.id}"
        )
      end
      private_class_method :notify!

      def self.otp_floors(user)
        consumed = OtpChallenge.where(user_id: user.id).where.not(consumed_at: nil)
                               .order(created_at: :desc).pick(:created_at)
        [consumed, expired_lock_end(user, :otp)].compact
      end
      private_class_method :otp_floors

      def self.expired_lock_end(user, kind)
        lock = SignInLock.latest_for(user, kind)
        return if lock.nil? || !expired?(lock, kind)

        lock.locked_at + limits(kind)[:duration]
      end
      private_class_method :expired_lock_end

      def self.expired?(lock, kind)
        Time.current >= lock.locked_at + limits(kind)[:duration]
      end
      private_class_method :expired?

      def self.limits(kind)
        config = RecordingStudioUser.config
        prefix = kind.to_sym == :password ? "password" : "otp"
        {
          max: config.public_send("#{prefix}_lockout_max_failures"),
          window: config.public_send("#{prefix}_lockout_window"),
          duration: config.public_send("#{prefix}_lockout_duration")
        }
      end
      private_class_method :limits
    end
  end
end
