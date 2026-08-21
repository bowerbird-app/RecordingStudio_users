# frozen_string_literal: true

require "test_helper"

class CurrentContextTest < Minitest::Test
  class DeviseController < ActionController::Base
    include RecordingStudioUsers::CurrentContext

    def devise_controller?
      true
    end
  end

  def setup
    RecordingStudioUsers.reset_configuration!
  end

  def teardown
    RecordingStudioUsers.reset_configuration!
  end

  def test_does_not_resolve_current_user_before_devise_verifies_csrf
    RecordingStudioUsers.configuration.current_actor_resolver = lambda do |**|
      flunk "Devise controllers must not resolve current_user in CurrentContext"
    end

    DeviseController.new.send(:recording_studio_users_set_current_actor)
  end
end
