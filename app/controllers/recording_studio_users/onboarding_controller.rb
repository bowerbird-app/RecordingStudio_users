# frozen_string_literal: true

module RecordingStudioUsers
  class OnboardingController < ApplicationController
    def show
      redirect_to invitations_path(root_recording_id: accessible_roots.first.id) if accessible_roots.any?
    end

    def create
      result = Services::CreateFirstRoot.call(
        name: params.dig(:workspace, :name),
        actor: current_actor,
        controller: self,
        device_key: device_key
      )

      if result.success?
        redirect_to invitations_path(root_recording_id: result.value.id),
                    notice: "Workspace ready. Invite your people."
      else
        flash.now[:alert] = result.error
        render :show, status: :unprocessable_entity
      end
    end

    private

    def accessible_roots
      @accessible_roots ||= RecordingStudioAccessible.root_recordings_for(actor: current_actor)
    end

    def device_key
      RecordingStudio::RootSwitchable::DeviceKey.fetch(controller: self)
    rescue RecordingStudio::RootSwitchable::DeviceKey::Unavailable
      nil
    end
  end
end
