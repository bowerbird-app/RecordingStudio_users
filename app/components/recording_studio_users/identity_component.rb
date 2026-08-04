# frozen_string_literal: true

module RecordingStudioUsers
  class IdentityComponent < ViewComponent::Base
    def initialize(user:, show_email: false, context: nil)
      @user = user
      @show_email = show_email
      @context = context
    end

    def call
      content_tag(:div, class: "flex items-center gap-3") do
        safe_join([render(AvatarComponent.new(user: @user, size: :small, context: @context)), identity_text])
      end
    end

    private

    def identity_text
      actor = @context[:actor] if @context.respond_to?(:[])
      email = if @show_email && RecordingStudioUsers.email_visible?(@user, actor:, context: @context)
                @user.email
              end
      content_tag(:div) do
        safe_join([
          content_tag(:div, RecordingStudioUsers.display_name(@user, context: @context), class: "font-medium"),
          (content_tag(:div, email, class: "text-sm text-gray-500") if email.present?)
        ].compact)
      end
    end
  end
end
