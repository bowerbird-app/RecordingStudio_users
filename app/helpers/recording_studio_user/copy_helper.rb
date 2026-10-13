# frozen_string_literal: true

module RecordingStudioUser
  module CopyHelper
    # Legacy-first Users copy for views. English comes from
    # `config/locales/en.yml` only — no English `default:` wrappers.
    def rsu_t(key, **options)
      RecordingStudioUser::Copy.legacy_t(key, **options)
    end
  end
end
