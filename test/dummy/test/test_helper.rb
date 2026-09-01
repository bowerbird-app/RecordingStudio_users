# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require_relative "support/profile_image_test_helper"

OmniAuth.config.test_mode = true

module AccessGrantTestHelper
  def bootstrap_owner_access!(actor, recording)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    return result.value if result.success?

    manager = access_manager_for(actor)
    if manager && already_bootstrapped?(result)
      result = RecordingStudioAccessible.grant_access(
        recording: recording,
        actor: actor,
        role: :admin,
        manager_actor: manager
      )
    end

    raise result.error if result.failure?

    result.value
  end

  def already_bootstrapped?(result)
    result.error.to_s.include?(
      RecordingStudioAccessible::Services::BootstrapOwnerAccess::ALREADY_BOOTSTRAPPED_MESSAGE
    )
  end

  def access_manager_for(actor)
    manager = User.find_by(email: "admin@admin.com")
    return manager if manager && manager.id != actor.id

    User.where.not(id: actor.id).first
  end
end

class ActionDispatch::IntegrationTest
  include AccessGrantTestHelper
end
