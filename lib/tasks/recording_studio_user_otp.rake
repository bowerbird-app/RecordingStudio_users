# frozen_string_literal: true

namespace :recording_studio_user do
  desc "Expire OTP challenges and clean up abandoned unconfirmed OTP users"
  task cleanup_otp: :environment do
    RecordingStudioUser::OtpChallenge.where("expires_at <= ?", Time.current).find_each do |challenge|
      challenge.revoke! unless challenge.consumed?
      challenge.clear_delivery_ciphertext!
    end

    RecordingStudioUser::OtpChallenge.where("consumed_at IS NOT NULL OR revoked_at IS NOT NULL")
                                     .where("updated_at < ?", 7.days.ago)
                                     .delete_all

    retention = RecordingStudioUser.config.unconfirmed_user_retention.ago
    user_class = RecordingStudioUser.config.user_class
    user_class.where(registered_with: "otp", confirmed_at: nil)
              .where("created_at < ?", retention)
              .find_each do |user|
      if defined?(RecordingStudioNotifications)
        RecordingStudioNotifications::Notification.where(recipient: user).destroy_all
      end
      RecordingStudioUser::OtpChallenge.where(user: user).delete_all
      user.destroy!
    end
  end
end
