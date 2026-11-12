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

    # Label for the inline code box. The document name and modal link come from
    # the same Terms helpers as the signup continue notice. The sentence is ours.
    def recording_studio_user_inline_terms
      documents = inline_terms_documents
      return if documents.blank?

      terms_modal_id = "inline-terms-#{SecureRandom.hex(4)}"
      privacy_modal_id = "inline-privacy-#{SecureRandom.hex(4)}"
      {
        label: inline_terms_sentence(documents, terms_modal_id, privacy_modal_id),
        modals: inline_terms_modals(documents, terms_modal_id, privacy_modal_id)
      }
    end

    private

    def inline_terms_documents
      return unless terms_notice_available?

      actor = recording_studio_terms_agree_actor
      root = recording_studio_terms_signup_root
      RecordingStudioTermsAndConditions.pending_published_list(actor, root).presence
    end

    def inline_terms_sentence(documents, terms_modal_id, privacy_modal_id)
      words = send(:continue_notice_document_words, documents, terms_modal_id, privacy_modal_id, link: true)
      app_name = RecordingStudioTermsAndConditions.configuration.app_name
      if app_name.present?
        t("recording_studio_user.otp_challenge.agree_to_terms_html", app_name: app_name, documents: words)
      else
        t("recording_studio_user.otp_challenge.agree_to_terms_without_app_html", documents: words)
      end
    end

    def inline_terms_modals(documents, terms_modal_id, privacy_modal_id)
      parts = []
      terms = send(:terms_document, documents)
      privacy = send(:privacy_document, documents)
      parts << send(:continue_notice_modal, terms, terms_modal_id) if terms
      parts << send(:continue_notice_modal, privacy, privacy_modal_id) if privacy
      safe_join(parts)
    end

    def terms_notice_available?
      defined?(RecordingStudioTermsAndConditions) &&
        RecordingStudioTermsAndConditions.respond_to?(:pending_published_list) &&
        respond_to?(:recording_studio_terms_continue_notice) &&
        respond_to?(:recording_studio_terms_signup_root) &&
        respond_to?(:recording_studio_terms_agree_actor)
    end
  end
end
