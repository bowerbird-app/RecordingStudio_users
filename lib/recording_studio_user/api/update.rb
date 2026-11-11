# frozen_string_literal: true

module RecordingStudioUser
  module Api
    class Update
      include ProfileRevision

      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        Access.authorize_edit!(context)
        user = Users.find!(context)
        attributes = Params.update_attributes(context)
        revise_profile!(user, attributes)
        Serialize.user(user.reload)
      rescue ActiveRecord::RecordInvalid => e
        Errors.from_record_invalid(e)
      end

      private

      attr_reader :context

      def revise_profile!(user, attributes)
        assignment = profile_revision(user, attributes)
        return if assignment.nil?

        Directory.record_profile!(user, actor: Access.actor_for(context), **assignment)
        user.touch
      end
    end
  end
end
