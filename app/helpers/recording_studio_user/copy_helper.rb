# frozen_string_literal: true

module RecordingStudioUser
  module CopyHelper
    # Legacy-first Users copy for views. Pass the original English as default:
    # so a host locale with no fallback never shows "translation missing".
    def rsu_t(key, default:, **options)
      RecordingStudioUser::Copy.legacy_t(key, default: default, **options)
    end
  end
end
