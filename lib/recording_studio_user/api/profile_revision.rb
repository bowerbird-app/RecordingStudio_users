# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module ProfileRevision
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
