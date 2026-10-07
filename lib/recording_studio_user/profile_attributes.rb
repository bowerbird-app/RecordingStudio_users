# frozen_string_literal: true

module RecordingStudioUser
  # Allowlisted extras on Profile jsonb. `:locale` is included by default.
  module ProfileAttributes
    module_function

    def merge(user, profile_attrs)
      existing = (Directory.profile_for(user)&.additional_profile_attributes || {}).stringify_keys
      submitted = if profile_attrs.key?(:additional_profile_attributes)
                    profile_attrs[:additional_profile_attributes]
                  else
                    {}
                  end
      filter(existing.merge((submitted.presence || {}).stringify_keys))
    end

    def filter(value)
      extras = (value.presence || {}).stringify_keys
      extras = extras.except(*Configuration::PROTECTED_PROFILE_ATTRIBUTES)
      extras = extras.slice(*RecordingStudioUser.config.additional_profile_attributes.map(&:to_s))
      key = ProfileLocales::PROFILE_KEY
      extras[key] = extras[key].to_s.strip if extras.key?(key)
      extras.delete(key) if extras[key].blank?
      extras
    end
  end
end
