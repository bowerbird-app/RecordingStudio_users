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
      [[blank_option_label, ""]] + options(current)
    end

    def label_for(code)
      return if code.blank?

      options(code).find { |_name, value| value.to_s == code.to_s }&.first
    end

    def site_default_language_name
      label_for(site_default_code).presence || site_default_code
    end

    def site_default_code
      extract_locale_code(internationalization_default_locale) || extract_locale_code(I18n.default_locale)
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

    def blank_option_label
      I18n.t("recording_studio_user.profile.use_site_default", language: site_default_language_name)
    end

    def extract_locale_code(value)
      return if value.blank?

      (value.respond_to?(:code) ? value.code : value).to_s
    end

    def internationalization_default_locale
      return unless defined?(::RecordingStudioInternationalization)
      return unless ::RecordingStudioInternationalization.respond_to?(:configuration)

      config = ::RecordingStudioInternationalization.configuration
      return unless config.respond_to?(:default_locale)

      config.default_locale
    rescue StandardError
      nil
    end
  end
end
