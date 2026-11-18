# frozen_string_literal: true

module RecordingStudioUser
  # Drops the raw token from the stored notice after the email send finishes.
  # The module lives here so a reload of the model does not stack the hook.
  module SignInLinkDelivery
    module AfterSend
      def deliver_one(notification, delivery)
        super
      ensure
        scrub_sign_in_link(notification, delivery)
      end

      def scrub_sign_in_link(notification, delivery)
        return unless notification.respond_to?(:notification_type)
        return unless notification.notification_type.to_s == "sign_in_link"

        # SignInLinkMail is defined beside SignInLink, so load that file first.
        mailer = RecordingStudioUser.const_get(:SignInLink).name && RecordingStudioUser::SignInLinkMail
        mailer.scrub_sent!(notification, delivery)
      end
    end

    def self.install!
      return unless defined?(RecordingStudioNotifications::DeliveryJob)

      singleton = RecordingStudioNotifications::DeliveryJob.singleton_class
      return if singleton.ancestors.include?(AfterSend)

      singleton.prepend(AfterSend)
    end
  end
end
