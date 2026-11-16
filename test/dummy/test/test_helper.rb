# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["RECORDING_STUDIO_MCP_POSTGRES_BUS"] = "0"

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

  # Early returns must not reach an ensure that assigns an unset local. That
  # writes nil over the default authorizer for every later example.
  def with_open_access_authorizer
    configuration = RecordingStudioAccessible.configuration
    original = configuration.access_management_authorizer
    configuration.access_management_authorizer = ->(**) { true }
    yield
  ensure
    configuration.access_management_authorizer = original
  end
end

module SignupTermsTestHelper
  def terms_library_root
    actor = Current.actor if defined?(Current) && Current.actor.present?
    actor ||= User.find_by(email: "admin@admin.com") || User.order(:created_at).first
    if actor.blank?
      actor = User.new(
        email: "terms-library@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      )
      actor.skip_confirmation!
      actor.save!
    end
    RecordingStudioTermsAndConditions.library_root(actor: actor)
  end

  def record_terms(root_recording, title:, body:)
    root_recording.record(RecordingStudioTermsAndConditions::Terms) do |terms|
      terms.title = title
      terms.body = body
    end
  end

  def publish_terms!(recording, slug:, status: "published")
    # Terms 0.19 drafts other live documents of the same kind after publish
    # and that write needs Current.actor.
    previous_actor = Current.actor
    Current.actor ||= User.find_by(email: "admin@admin.com") || User.order(:created_at).first
    if Current.actor.blank?
      publisher = User.new(
        email: "terms-publisher@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      )
      publisher.skip_confirmation!
      publisher.save!
      Current.actor = publisher
    end
    RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      attributes: { slug: slug, status: status }
    ).value!
  ensure
    Current.actor = previous_actor
  end

  # Terms 0.21 gates on the shared library. Dummy seeds leave those Terms live,
  # so integration users that are not exercising Accept need a receipt first.
  def accept_pending_live_terms!(user)
    return if user.blank?

    RecordingStudioTermsAndConditions.pending_published_list(user).each do |terms|
      RecordingStudioTermsAndConditions.accept!(user, terms, { "source" => "continue_notice" })
    end
  end

  def without_live_terms_fallback
    mod = RecordingStudioTermsAndConditions.singleton_class
    mod.class_eval do
      alias_method :pending_published_list_with_live_terms, :pending_published_list
      define_method(:pending_published_list) { |*_args, **_kwargs| [] }
    end
    yield
  ensure
    mod.class_eval do
      alias_method :pending_published_list, :pending_published_list_with_live_terms
      remove_method :pending_published_list_with_live_terms
    end
  end
end

class ActionDispatch::IntegrationTest
  include AccessGrantTestHelper
  include PushTestHelper
  include SignupTermsTestHelper
end
