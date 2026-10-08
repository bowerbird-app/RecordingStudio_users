# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require_relative "support/profile_image_test_helper"
require_relative "support/push_test_helper"

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

module SignupTermsTestHelper
  def record_terms(root_recording, title:, body:)
    root_recording.record(RecordingStudioTermsAndConditions::Terms) do |terms|
      terms.title = title
      terms.body = body
    end
  end

  def publish_terms!(recording, slug:, status: "published")
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: slug, status: status }
    ).value!
  end

  # Terms 0.7.7+ gates against the first root with live Terms when the current
  # workspace has none. Dummy seeds leave live Terms under My workspace, so
  # integration users that are not exercising Accept need a receipt first.
  def accept_pending_live_terms!(user)
    root = RecordingStudioTermsAndConditions::Gate.first_root_with_live_terms
    return if user.blank? || root.blank?

    RecordingStudioTermsAndConditions.pending_published_list(user, root).each do |terms|
      RecordingStudioTermsAndConditions.accept!(user, terms, { "source" => "continue_notice" })
    end
  end

  def without_live_terms_fallback
    gate = RecordingStudioTermsAndConditions::Gate
    original = gate.method(:first_root_with_live_terms)
    gate.define_singleton_method(:first_root_with_live_terms) { nil }
    yield
  ensure
    gate.define_singleton_method(:first_root_with_live_terms, original)
  end
end

class ActionDispatch::IntegrationTest
  include AccessGrantTestHelper
  include PushTestHelper
  include SignupTermsTestHelper
end
