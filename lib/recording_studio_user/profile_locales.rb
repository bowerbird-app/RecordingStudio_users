# frozen_string_literal: true

module RecordingStudioUser
  # Language choices for Profile extras["locale"]. Internationalization stores the
  # same key. When that gem is loaded, use its available locales; otherwise offer
  # the common starting set it documents (en / fr / ja).
  module ProfileLocales
    PROFILE_KEY = "locale"
    STARTING_SET = [
      %w[English en],
      %w[Français fr],
      %w[日本語 ja]
    ].freeze
    SITE_DEFAULT_LABEL = "Use the site default"

    module_function

    def allowlisted?
      RecordingStudioUser.config.additional_profile_attributes.include?(:locale)
    end

    def options(current = nil)
      list = from_internationalization.presence || STARTING_SET
      code = current.to_s
      return list if code.blank? || list.any? { |_name, value| value.to_s == code }

      list + [[code, code]]
    end

    def select_options(current = nil)
      [[SITE_DEFAULT_LABEL, ""]] + options(current)
    end

    def label_for(code)
      return if code.blank?

      options(code).find { |_name, value| value.to_s == code.to_s }&.first
    end

    def from_internationalization
      return unless defined?(::RecordingStudioInternationalization)
      return unless ::RecordingStudioInternationalization.respond_to?(:configuration)

      locales = ::RecordingStudioInternationalization.configuration.available_locales
      mapped = Array(locales).map { |locale| [locale.name, locale.code.to_s] }
      mapped.presence
    rescue StandardError
      nil
    end
  end
end
