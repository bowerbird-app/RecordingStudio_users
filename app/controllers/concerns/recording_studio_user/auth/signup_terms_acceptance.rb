# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    # Soft hook: when Terms and Conditions is installed, continuing
    # create-password accepts pending live Terms. Without that gem this is a no-op.
    module SignupTermsAcceptance
      private

      def accept_pending_terms_on_signup!(actor)
        return unless terms_acceptance_available?
        return if actor.blank?

        root = RecordingStudioTermsAndConditions::Gate.root_for_signup(self)
        return if root.blank?

        RecordingStudioTermsAndConditions.pending_published_list(actor, root).each do |terms|
          RecordingStudioTermsAndConditions.accept!(actor, terms, { "source" => "continue_notice" })
        end
      rescue RecordingStudioTermsAndConditions::NotLive
        nil
      end

      def terms_acceptance_available?
        defined?(RecordingStudioTermsAndConditions::Gate) &&
          RecordingStudioTermsAndConditions.respond_to?(:pending_published_list) &&
          RecordingStudioTermsAndConditions.respond_to?(:accept!)
      end
    end
  end
end
