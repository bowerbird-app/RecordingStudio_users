# frozen_string_literal: true

require "test_helper"

class ArchitectureTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_user_root_is_uuid_backed_and_uniquely_owned
    migration = source("db/migrate/20250101000001_create_recording_studio_users_user_roots.rb")

    assert_includes migration, "id: :uuid"
    assert_includes migration, "index: {unique: true}"
    assert_includes migration, "null: false"
  end

  def test_user_is_actor_not_recordable
    concern = source("app/models/concerns/recording_studio_users/user.rb")

    assert_includes concern, "RecordingStudio.actor(self)"
    refute_includes concern, "recording_studio_recordable"
  end

  def test_recordable_declarations_are_strict_and_scoped
    user_root = source("app/models/recording_studio_users/user_root.rb")
    profile = source("app/models/recording_studio_users/profile.rb")

    assert_includes user_root, "root: true"
    assert_includes profile, "root: false"
    assert_includes profile, 'allowed_parent_types: ["RecordingStudioUsers::UserRoot"]'
    assert_includes profile, "strict: true"
  end

  def test_avatar_services_delegate_to_attachable_public_services
    service = source("lib/recording_studio_users/services/avatar_mutation.rb")

    assert_includes service, "RecordingStudioAttachable::RecordAttachmentUpload"
    assert_includes service, "RecordingStudioAttachable::ReplaceAttachmentFile"
    assert_includes service, "RecordingStudioAttachable::RemoveAttachment"
    refute_includes service, "ActiveStorage::Blob"
  end

  def test_dependency_owned_audit_records_are_not_created_directly
    production_sources = Dir[File.join(ROOT, "{app,lib}/**/*.rb")].map { |path| File.read(path) }.join("\n")

    refute_match(/RecordingStudio::Access\.create/, production_sources)
    refute_match(/RecordingStudio::Event\.create/, production_sources)
    refute_match(/RecordingStudioAttachable::Attachment\.create/, production_sources)
    refute_includes production_sources, "AccessCreationContext"
  end

  private

  def source(relative_path)
    File.read(File.join(ROOT, relative_path))
  end
end
