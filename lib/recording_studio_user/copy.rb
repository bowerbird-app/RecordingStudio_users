# frozen_string_literal: true

require "i18n"

module RecordingStudioUser
  # Rails I18n lookups for Users user-facing copy. English ships only in
  # `config/locales/en.yml` — callers never pass an English `default:`.
  # Prefer nested `recording_studio.users.*` keys; wave-1 keys still ship under
  # `recording_studio_user.*` and are looked up first with the nested key as
  # the I18n key fallback. A missing key behaves like bare `I18n.t` (translation
  # missing / raise-on-missing).
  module Copy
    PREFIX = "recording_studio.users"
    LEGACY_PREFIX = "recording_studio_user"

    module_function

    def t(key, **options)
      I18n.t("#{PREFIX}.#{key}", **options)
    end

    # Legacy-first lookup for keys that still ship under
    # `recording_studio_user.*` (wave-1 callers and host overrides).
    # Optional `default:` accepts only further I18n key symbols / arrays of
    # keys — never English string fallbacks.
    def legacy_t(key, **options)
      nested = :"#{PREFIX}.#{key}"
      extra = options.delete(:default)
      defaults =
        case extra
        when nil then [nested]
        when Array then [nested, *extra]
        else [nested, extra]
        end

      I18n.t("#{LEGACY_PREFIX}.#{key}", **options, default: defaults)
    end
  end
end
