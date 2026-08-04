# frozen_string_literal: true

module RecordingStudioUsers
  class UsersController < ApplicationController
    def search
      result = RecordingStudioUsers.search_users(
        query: params[:q],
        actor: current_recording_studio_user,
        root_recording: authorized_root_recording,
        limit: params[:limit],
        exclude_ids: params.fetch(:exclude, []),
        context: {actor: current_recording_studio_user}
      )
      return render json: {items: picker_items(result.value)} if result.success?

      render json: {items: [], error: result.error}, status: :forbidden
    end

    private

    def authorized_root_recording
      return if params[:root_recording_id].blank?

      RecordingStudio::Recording.unscoped.find(params[:root_recording_id])
    end

    def picker_items(users)
      users.map do |user|
        avatar = RecordingStudioUsers.avatar_for(user, size: :small, context: search_context)
        item = {
          id: user.id,
          kind: "record",
          title: RecordingStudioUsers.display_name(user, context: search_context),
          name: RecordingStudioUsers.display_name(user, context: search_context),
          thumbnail_url: avatar.image? ? avatar.image_path : nil,
          meta: avatar.image? ? nil : avatar.initials,
          payload: {user_id: user.id}
        }
        item[:disabled] = true if disabled_user_ids.include?(user.id.to_s)
        if RecordingStudioUsers.email_visible?(user, actor: current_recording_studio_user, context: search_context)
          item[:description] = user.email
        end
        item.compact
      end
    end

    def search_context
      @search_context ||= {actor: current_recording_studio_user}
    end

    def disabled_user_ids
      @disabled_user_ids ||= Array(params[:disabled]).compact_blank.first(100).map(&:to_s)
    end
  end
end
