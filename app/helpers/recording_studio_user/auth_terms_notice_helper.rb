# frozen_string_literal: true

module RecordingStudioUser
  # Soft Terms notice on create-password. Hosts that load
  # recording_studio_terms_and_conditions get the continue-notice when live
  # Terms are still pending. Without that gem this helper is a no-op.
  # TnC 0.6.3+ Gate.root_for_signup already falls back when the current
  # workspace has no live Terms.
  module AuthTermsNoticeHelper
    def recording_studio_user_signup_terms_notice
      return unless terms_notice_available?

      actor = recording_studio_terms_agree_actor
      root = recording_studio_terms_signup_root
      pending = RecordingStudioTermsAndConditions.pending_published_list(actor, root)
      return if pending.blank?

      recording_studio_terms_continue_notice(actor: actor, root: root, pending: pending)
    end

    private

    def terms_notice_available?
      defined?(RecordingStudioTermsAndConditions) &&
        RecordingStudioTermsAndConditions.respond_to?(:pending_published_list) &&
        respond_to?(:recording_studio_terms_continue_notice) &&
        respond_to?(:recording_studio_terms_signup_root) &&
        respond_to?(:recording_studio_terms_agree_actor)
    end
  end
end
