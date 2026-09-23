# frozen_string_literal: true

module Dummy
  # One live Terms record under the dummy signup workspace, plus Acceptance
  # receipts. Dummy-only integration seam — not a Users production dependency.
  module SignupTerms
    WORKSPACE_NAME = "My workspace"
    SLUG = "terms-and-conditions"
    SEED_PROVENANCE = { "source" => "seed" }.freeze

    module_function

    def workspace
      Workspace.find_or_create_by!(name: WORKSPACE_NAME)
    end

    def root_recording
      RecordingStudio.root_recording_for(workspace)
    end

    def ensure_live!(actor:)
      title = RecordingStudioTermsAndConditions::SampleTerms::TITLE
      body = RecordingStudioTermsAndConditions::SampleTerms::BODY
      recording = existing_terms_recording

      if recording.blank?
        recording = root_recording.record(
          RecordingStudioTermsAndConditions::Terms,
          actor: actor
        ) do |terms|
          terms.title = title
          terms.body = body
        end
        publish!(recording)
      elsif recording.recordable.title != title || recording.recordable.body != body
        recording = RecordingStudioTermsAndConditions::TermsWrite.call(
          recording: recording,
          actor: actor,
          title: title,
          body: body
        )
        publish!(recording)
      elsif recording.try(:current_publishable)&.try(:slug) != SLUG ||
            !recording.currently_published?
        publish!(recording)
      end

      recording
    end

    def accept_seeded!(actor)
      terms = RecordingStudioTermsAndConditions.current_published_for(workspace)
      return if actor.blank? || terms.blank?

      RecordingStudioTermsAndConditions.accept!(actor, terms, SEED_PROVENANCE)
    end

    def existing_terms_recording
      RecordingStudio::Recording.find_by(
        recordable_type: RecordingStudioTermsAndConditions::Terms.name,
        root_recording: root_recording,
        trashed_at: nil
      )
    end

    def publish!(recording)
      RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: recording,
        attributes: { slug: SLUG, status: "published" }
      ).value!
    end
  end
end
