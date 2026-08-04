# frozen_string_literal: true

module RecordingStudioUsers
  Avatar = Data.define(:image_path, :initials, :alt_text, :width, :height) do
    def image? = image_path.present?
  end
end
