# frozen_string_literal: true

require "i18n"

module RecordingStudioUser
  # Rails I18n lookups for Users user-facing copy. Every call passes
  # `default:` English so a host locale without a fallback never shows
  # "translation missing". Prefer nested `recording_studio.users.*` keys;
  # wave-1 keys still ship under `recording_studio_user.*` and are looked up
  # first with the nested key as the next default.
  module Copy
    PREFIX = "recording_studio.users"
    LEGACY_PREFIX = "recording_studio_user"

    module_function

    def t(key, **options)
      I18n.t("#{PREFIX}.#{key}", **options)
    end

    # Legacy-first lookup for keys that still ship under
    # `recording_studio_user.*` (wave-1 callers and host overrides).
    def legacy_t(key, default:, **options)
      I18n.t(
        "#{LEGACY_PREFIX}.#{key}",
        **options,
        default: [:"#{PREFIX}.#{key}", default]
      )
    end
  end
end
