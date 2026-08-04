# frozen_string_literal: true

module RecordingStudioUsers
  class NameComponent < ViewComponent::Base
    def initialize(user:, context: nil, link: true)
      @user = user
      @context = context
      @link = link
    end

    def call
      name = RecordingStudioUsers.display_name(@user, context: @context)
      actor = @context[:actor] if @context.respond_to?(:[])
      path = RecordingStudioUsers.profile_path_for(@user, actor:, context: @context)
      return name unless @link && path

      link_to(name, path)
    end
  end
end
