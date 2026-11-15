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

    def root_recording(actor: nil)
      RecordingStudio.create_root_recording!(workspace, actor: actor)
    end

    def ensure_live!(actor:)
      title = RecordingStudioTermsAndConditions::SampleTerms::TITLE
      body = RecordingStudioTermsAndConditions::SampleTerms::BODY
      root = root_recording(actor: actor)
      recording = existing_terms_recording(root)

      if recording.blank?
        recording = root.record(
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

    def existing_terms_recording(root = root_recording)
      RecordingStudio::Recording.kept.find_by(
        recordable_type: RecordingStudioTermsAndConditions::Terms.name,
        root_recording: root
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
