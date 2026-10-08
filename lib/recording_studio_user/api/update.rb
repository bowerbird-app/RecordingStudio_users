# frozen_string_literal: true

module RecordingStudioUser
  module Api
    class Update
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        Access.authorize_edit!(context)
        user = find_user!
        attributes = Params.update_attributes(context)
        update_email!(user, attributes[:email])
        revise_profile!(user, attributes)
        Serialize.user(user.reload)
      rescue ActiveRecord::RecordInvalid => e
        Errors.from_record_invalid(e)
      end

      private

      attr_reader :context

      def find_user!
        user = RecordingStudioUser.config.user_class.find_by(id: Params.record_id(context))
        Errors.not_found! if user.blank?

        user
      end

      def update_email!(user, email)
        return if email.blank?
        return if email.to_s.strip.casecmp?(user.email.to_s)

        user.email = email.to_s.strip
        user.save!
      end

      def revise_profile!(user, attributes)
        assignment = profile_revision(user, attributes)
        return if assignment.nil?

        Directory.record_profile!(user, actor: Access.actor_for(context), **assignment)
      end

      def profile_revision(user, attributes)
        profile_attrs = attributes.slice(*Directory::PROFILE_ATTRIBUTE_KEYS)
        extras = profile_attrs[:additional_profile_attributes]
        named = profile_attrs.except(:additional_profile_attributes).compact_blank
        return if named.blank? && extras.blank?

        named_profile_fields(Directory.profile_for(user), named).merge(
          additional_profile_attributes: extras.presence
        )
      end

      def named_profile_fields(profile, named)
        {
          first_name: named.fetch(:first_name, profile&.first_name),
          last_name: named.fetch(:last_name, profile&.last_name),
          time_zone: named.fetch(:time_zone, profile&.time_zone)
        }
      end
    end
  end
end
