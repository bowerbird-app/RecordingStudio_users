# frozen_string_literal: true

module RecordingStudioUser
  module Auth
    # Soft hook: when Terms and Conditions is installed, continuing
    # create-password accepts pending live Terms. Without that gem this is a no-op.
    # TnC 0.6.3+ Gate.root_for_signup already falls back when the current
    # workspace has no live Terms.
    module SignupTermsAcceptance
      private

      def accept_pending_terms_on_signup!(actor, source: "continue_notice")
        return unless terms_acceptance_available?
        return if actor.blank?

        root = RecordingStudioTermsAndConditions::Gate.root_for_signup(self)
        return if root.blank?

        RecordingStudioTermsAndConditions.pending_published_list(actor, root).each do |terms|
          RecordingStudioTermsAndConditions.accept!(actor, terms, { "source" => source })
        end
      rescue RecordingStudioTermsAndConditions::NotLive
        nil
      end

      def pending_signup_terms?
        return false unless terms_acceptance_available?

        root = RecordingStudioTermsAndConditions::Gate.root_for_signup(self)
        return false if root.blank?

        RecordingStudioTermsAndConditions.pending_published_list(signup_terms_actor, root).any?
      end

      def signup_terms_actor
        return current_user if respond_to?(:current_user, true) && current_user
        return Current.actor if defined?(Current) && Current.respond_to?(:actor)

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
