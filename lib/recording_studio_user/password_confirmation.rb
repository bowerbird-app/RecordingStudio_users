# frozen_string_literal: true

module RecordingStudioUser
  module PasswordConfirmation
    SESSION_KEY = :password_signup_user_id
    THREAD_KEY = :recording_studio_user_password_confirmation_session

    module Confirms
      def confirm(...)
        PasswordConfirmation.clear_password_unless_same_signup!(self)
        super
      end
    end

    module BindsSession
      extend ActiveSupport::Concern

      included do
        around_action :bind_password_confirmation_session
      end

      private

      def bind_password_confirmation_session(&)
        PasswordConfirmation.bind(session, &)
      end
    end

    class << self
      def pending?(user)
        return false if user.blank?
        return false unless user.respond_to?(:registered_with_password?) && user.registered_with_password?
        return false if user.respond_to?(:confirmed?) && user.confirmed?

        true
      end

      def mark!(session, user)
        return if session.nil? || user.blank?

        session[SESSION_KEY] = user.id
      end

      def bind(session, &block)
        previous = Thread.current[THREAD_KEY]
        Thread.current[THREAD_KEY] = session
        block.call
      ensure
        Thread.current[THREAD_KEY] = previous
      end

      def clear_password_unless_same_signup!(user)
        return if user.blank? || confirmed?(user)

        keep = same_signup?(user)
        forget_signup!(user)
        return if keep || !password_digest?(user)

        clear_password!(user)
      end

      def confirmed?(user)
        user.respond_to?(:confirmed?) && user.confirmed?
      end

      def password_digest?(user)
        user.respond_to?(:encrypted_password) && user.encrypted_password.present?
      end

      def same_signup?(user)
        session = Thread.current[THREAD_KEY]
        return false if session.blank?

        session[SESSION_KEY].to_s == user.id.to_s
      end

      def forget_signup!(user)
        session = Thread.current[THREAD_KEY]
        return if session.blank?
        return unless session[SESSION_KEY].to_s == user.id.to_s

        session.delete(SESSION_KEY)
      end

      def clear_password!(user)
        user.encrypted_password = ""
        user.remember_created_at = nil if user.respond_to?(:remember_created_at=)
        user.instance_variable_set(:@password, nil)
      end
    end
  end
end
