# frozen_string_literal: true

module RecordingStudioUsers
  module ApplicationHelper
    def recording_studio_user_name(user, context: recording_studio_user_context, link: false)
      component = RecordingStudioUsers::NameComponent.new(user:, context:, link:)
      render(component)
    end

    def recording_studio_user_avatar(user, size: :small, context: recording_studio_user_context)
      render RecordingStudioUsers::AvatarComponent.new(user:, size:, context:)
    end

    def recording_studio_user_identity(user, show_email: false, context: recording_studio_user_context)
      render RecordingStudioUsers::IdentityComponent.new(user:, show_email:, context:)
    end

    def recording_studio_user_byline(user, context: recording_studio_user_context)
      render RecordingStudioUsers::BylineComponent.new(user:, context:)
    end

    def recording_studio_user_picker(id:, multiple: false, exclusions: [], disabled: [], context: {})
      render FlatPack::Picker::Component.new(
        id:,
        title: multiple ? "Select users" : "Select a user",
        accepted_kinds: [:record],
        selection_mode: multiple ? :multiple : :single,
        search_mode: :remote,
        search_endpoint: recording_studio_users.users_search_path(
          exclude: Array(exclusions).map(&:id),
          disabled: Array(disabled).map(&:id)
        ),
        empty_state_text: "No users found",
        context:
      )
    end

    private

    def recording_studio_user_context
      { actor: RecordingStudioUsers.current_actor(controller), view_context: self }
    end
  end
end
