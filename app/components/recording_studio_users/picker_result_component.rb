# frozen_string_literal: true

module RecordingStudioUsers
  class PickerResultComponent < ViewComponent::Base
    def initialize(user:, context: nil, disabled: false)
      @user = user
      @context = context
      @disabled = disabled
    end

    def call
      content_tag(:div, class: "flex items-center justify-between gap-3") do
        safe_join([
          render(IdentityComponent.new(user: @user, context: @context)),
          (render(FlatPack::Badge::Component.new(text: "Unavailable", style: :default, size: :sm)) if @disabled)
        ].compact)
      end
    end
  end
end
