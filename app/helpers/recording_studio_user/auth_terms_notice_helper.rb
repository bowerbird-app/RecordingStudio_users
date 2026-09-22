# frozen_string_literal: true

module RecordingStudioUser
  # Soft Terms notice on create-password. Hosts that load
  # recording_studio_terms_and_conditions get the continue-notice when live
  # Terms are still pending. Without that gem this helper is a no-op.
  module AuthTermsNoticeHelper
    def recording_studio_user_signup_terms_notice
      return unless terms_notice_available?

      actor = recording_studio_terms_agree_actor
      root, pending = signup_terms_notice_root_and_pending(actor)
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

    def signup_terms_notice_root_and_pending(actor)
      root = recording_studio_terms_signup_root
      pending = RecordingStudioTermsAndConditions.pending_published_list(actor, root)
      return [root, pending] if pending.present?

      fallback = signup_terms_fallback_root
      return [root, pending] if fallback.blank? || fallback == root

      fallback_pending = RecordingStudioTermsAndConditions.pending_published_list(actor, fallback)
      return [fallback, fallback_pending] if fallback_pending.present?

      [root, pending]
    end

    def signup_terms_fallback_root
      return unless defined?(RecordingStudioTermsAndConditions::Gate)
      return unless RecordingStudioTermsAndConditions::Gate.respond_to?(:first_root_with_live_terms)

      RecordingStudioTermsAndConditions::Gate.first_root_with_live_terms
    end
  end
end
