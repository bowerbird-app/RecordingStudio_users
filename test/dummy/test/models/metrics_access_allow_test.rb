# frozen_string_literal: true

require "test_helper"

class MetricsAccessAllowTest < ActiveSupport::TestCase
  include AccessGrantTestHelper

  test "can_view? is true for staff granted AdminRoot view" do
    owner = create_staff_user("metrics-owner-#{SecureRandom.hex(4)}@example.com")
    staff = create_staff_user("metrics-staff-#{SecureRandom.hex(4)}@example.com")
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    recording = RecordingStudio.root_recording_for(admin_root)
    bootstrap_owner_access!(owner, recording)
    grant = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: staff,
      role: :view,
      manager_actor: owner
    )

    assert grant.success?, grant.error.to_s
    assert RecordingStudioUser::Api::Access.can_view?(access_context_for(staff))
  end

  private

  def access_context_for(actor)
    grant = Struct.new(:actor).new(actor)
    context = Object.new
    context.define_singleton_method(:access_grant) { grant }
    context
  end

  def create_staff_user(email)
    user = User.new(
      email: email,
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
    user.save!
    user
  end
end
