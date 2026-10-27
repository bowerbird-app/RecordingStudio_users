# frozen_string_literal: true

# Site Settings and OAuth still include this concern. Recording Studio 6.1
# removed it. Keep the old layout contract for those engines until they move
# to recording_studio_layout.
unless defined?(RecordingStudio::UsesDefaultLayout)
  module RecordingStudio
    module UsesDefaultLayout
      extend ActiveSupport::Concern

      included do
        layout "recording_studio/default_layout"
        helper RecordingStudio::LayoutHelper
      end
    end
  end
end

RecordingStudio.configure do |config|
  # Registered delegated_type recordables (strings or classes)
  config.recordable_types = [
    "Workspace",
    "Folder",
    "Page",
    "AdminRoot",
    "RecordingStudioUser::People",
    "RecordingStudioUser::Profile",
    "RecordingStudioAttachable::Attachment",
    "RecordingStudioSiteSettings::SiteSetting",
    "RecordingStudioTermsAndConditions::Terms",
    "RecordingStudioPublishable::Publishable"
  ]
  config.recordable_types += [
    "RecordingStudio::Access",
    "RecordingStudioApi::ApiClient",
    "RecordingStudioApi::ApiCredential",
    "RecordingStudioApi::ApiAccessToken",
    "RecordingStudioApi::AdminApi"
  ]

  # Require each configured ActiveRecord type to call recording_studio_recordable.
  config.require_recordable_declarations = true

  # Actor resolver for events when no actor is explicitly supplied
  config.actor = -> { Current.actor }

  # Emit ActiveSupport::Notifications events
  config.event_notifications_enabled = true

  # Idempotency behavior for log_event!
  config.idempotency_mode = :return_existing # or :raise

  # Recordable duplication strategy for revisions
  config.recordable_dup_strategy = :dup
end
