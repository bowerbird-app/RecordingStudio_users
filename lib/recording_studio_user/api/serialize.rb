# frozen_string_literal: true

module RecordingStudioUser
  module Api
    module Serialize
      SECRET_ATTRIBUTE_NAMES = %w[
        encrypted_password
        password
        password_confirmation
        reset_password_token
        reset_password_sent_at
        remember_created_at
        confirmation_token
        confirmation_sent_at
        unlock_token
        encrypted_otp_secret
        otp_secret
        consumed_timestep
        otp_backup_codes
      ].freeze

      module_function

      def user(record)
        payload = user_payload(record)
        assert_no_secrets!(payload)
        payload
      end

      def user_payload(record)
        timestamps(record)
          .merge(identity_fields(record))
          .merge(profile_fields(Directory.profile_for(record)))
      end

      def identity_fields(record)
        {
          id: record.id,
          email: record.email,
          registered_with: registered_with(record),
          identity_providers: identity_provider_names(record)
        }
      end

      def profile_fields(profile)
        extras = ProfileAttributes.filter(profile&.additional_profile_attributes)
        {
          first_name: profile&.first_name,
          last_name: profile&.last_name,
          time_zone: profile&.time_zone,
          additional_profile_attributes: extras
        }
      end

      def timestamps(record)
        {
          confirmed_at: timestamp(record, :confirmed_at),
          created_at: timestamp(record, :created_at),
          updated_at: timestamp(record, :updated_at)
        }
      end

      def collection(records, meta:)
        { records: records.map { |record| user(record) }, meta: meta }
      end

      def identity_provider_names(record)
        return [] unless record.respond_to?(:identities)

        identities = record.identities
        identities = identities.order(:provider) if identities.respond_to?(:order)
        identities.filter_map { |identity| identity.provider.to_s.presence }
      end

      def registered_with(record)
        return unless record.respond_to?(:registered_with)

        record.registered_with
      end

      def timestamp(record, attribute)
        return unless record.respond_to?(attribute)

        record.public_send(attribute)
      end

      def assert_no_secrets!(payload)
        leaked = SECRET_ATTRIBUTE_NAMES.select { |name| payload.key?(name.to_sym) || payload.key?(name) }
        raise "Refusing to serialize secret user fields: #{leaked.join(', ')}" if leaked.any?
      end
    end
  end
end
