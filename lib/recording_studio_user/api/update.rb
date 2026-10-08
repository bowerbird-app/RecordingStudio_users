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
      rescue ActiveRecord::RecordInvalid => error
        Errors.from_record_invalid(error)
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
        profile_attrs = attributes.slice(*Directory::PROFILE_ATTRIBUTE_KEYS)
        extras = profile_attrs[:additional_profile_attributes]
        extras_submitted = extras.present?
        named = profile_attrs.except(:additional_profile_attributes).compact_blank
        return if named.blank? && !extras_submitted

        profile = Directory.profile_for(user)
        Directory.record_profile!(
          user,
          actor: Access.actor_for(context),
          first_name: named.key?(:first_name) ? named[:first_name] : profile&.first_name,
          last_name: named.key?(:last_name) ? named[:last_name] : profile&.last_name,
          time_zone: named.key?(:time_zone) ? named[:time_zone] : profile&.time_zone,
          additional_profile_attributes: extras_submitted ? extras : nil
        )
      end
    end
  end
end
