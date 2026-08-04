# frozen_string_literal: true

module RecordingStudioUsers
  class BylineComponent < ViewComponent::Base
    def initialize(user:, context: nil)
      @user = user
      @context = context
    end

    def call
      content_tag(:span, class: "inline-flex items-center gap-2") do
        safe_join([
                    render(AvatarComponent.new(user: @user, size: :small, context: @context)),
                    render(NameComponent.new(user: @user, context: @context, link: true))
                  ])
      end
    end
  end
end
