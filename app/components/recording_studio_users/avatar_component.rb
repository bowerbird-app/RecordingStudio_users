# frozen_string_literal: true

module RecordingStudioUsers
  class AvatarComponent < ViewComponent::Base
    FLATPACK_SIZES = {small: :sm, medium: :md, large: :xl}.freeze

    def initialize(user:, size: :medium, context: nil)
      @user = user
      @size = size.to_sym
      @context = context
    end

    def call
      avatar = RecordingStudioUsers.avatar_for(@user, size: @size, context: @context)
      render FlatPack::Avatar::Component.new(
        src: avatar.image_path,
        alt: avatar.alt_text,
        initials: avatar.initials,
        name: RecordingStudioUsers.display_name(@user, context: @context),
        size: FLATPACK_SIZES.fetch(@size)
      )
    end
  end
end
