# frozen_string_literal: true

module RecordingStudioUsers
  module ApplicationHelper
    def membership_user_label(user)
      RecordingStudioUsers.configuration.user_label_for(user: user)
    end

    def membership_role_options
      RecordingStudio::Access.roles.keys.map { |role| [role.humanize, role] }
    end

    def current_workspace_label
      recordable = current_root_recording.recordable
      return recordable.name if recordable.respond_to?(:name)
      return recordable.title if recordable.respond_to?(:title)

      recordable.class.model_name.human
    end
  end
end
