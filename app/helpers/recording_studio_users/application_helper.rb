# frozen_string_literal: true

module RecordingStudioUsers
  module ApplicationHelper
    def membership_actor(access_recording)
      access_recording.recordable.actor
    end

    def membership_email(access_recording)
      RecordingStudioUsers.configuration.email_for(actor: membership_actor(access_recording))
    end

    # The switcher offers every role up to the real Accessible ceiling, so a
    # demoted admin can always climb back to their own access.
    def available_operating_roles(root_recording)
      ceiling = RecordingStudioAccessible.role_for(actor: current_actor, recording: root_recording)
      RecordingStudioUsers::Authorization::ROLES.select do |role|
        RecordingStudio::AccessRoles.satisfies?(role: ceiling, minimum_role: role)
      end
    end

    def membership_role_form(access_recording, root_recording)
      form_with(
        url: membership_path(access_recording, root_recording_id: root_recording.id),
        scope: :membership,
        method: :patch,
        class: "flex items-end gap-2"
      ) do
        safe_join([
                    render(FlatPack::Select::Component.new(
                             name: "membership[role]",
                             options: RecordingStudioUsers::Authorization::ROLES.map { |role| [role.titleize, role] },
                             value: access_recording.recordable.role
                           )),
                    render(FlatPack::Button::Component.new(text: "Save", style: :secondary, size: :sm, type: :submit))
                  ])
      end
    end

    def membership_revoke_form(access_recording, root_recording)
      form_with(
        url: membership_path(access_recording, root_recording_id: root_recording.id),
        method: :delete,
        data: { turbo_confirm: "Remove this person’s access?" }
      ) do
        render FlatPack::Button::Component.new(text: "Remove", style: :ghost, size: :sm, type: :submit)
      end
    end
  end
end
