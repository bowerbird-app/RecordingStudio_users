# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_user/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  def test_template_creates_people_and_profile_tables
    template = File.read(
      File.expand_path(
        "../lib/generators/recording_studio_user/migrations/templates/" \
        "create_recording_studio_user_people_and_profiles.rb.tt",
        __dir__
      )
    )

    assert_includes template, "create_table :recording_studio_user_people"
    assert_includes template, "create_table :recording_studio_user_profiles"
    assert_includes template, "t.uuid :user_id, null: false"
    assert_includes template, "t.string :first_name, null: false"
    assert_includes template, "t.string :last_name, null: false"
    assert_includes template, "t.string :time_zone, null: false, default: \"UTC\""
    assert_includes template, "t.jsonb :additional_profile_attributes"
    refute_includes template, "t.timestamps"
    assert_includes template, "add_foreign_key :recording_studio_user_profiles, :users"
  end

  def test_restore_template_creates_identities_table_only_when_missing
    template = File.read(
      File.expand_path(
        "../lib/generators/recording_studio_user/migrations/templates/" \
        "restore_recording_studio_user_identities.rb.tt",
        __dir__
      )
    )

    assert_includes template, "class RestoreRecordingStudioUserIdentities"
    assert_includes template, "return if table_exists?(:recording_studio_user_identities)"
    assert_includes template, "create_table :recording_studio_user_identities"
    assert_includes template, "t.uuid :user_id, null: false"
    assert_includes template, "t.string :provider, :uid, null: false"
    assert_includes template, "t.string :email"
    assert_includes template, "t.index %i[provider uid], unique: true"
    assert_includes template, "t.foreign_key :users, column: :user_id"
    refute_includes template, "oauth_token"
  end

  def test_generator_skips_when_the_host_already_has_the_migration
    generator = RecordingStudioUser::Generators::MigrationsGenerator.new
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      File.write(
        File.join(dir, "db/migrate/20260821000000_create_recording_studio_user_people_and_profiles.rb"),
        "# existing\n"
      )
      File.write(
        File.join(dir, "db/migrate/20260831000000_restore_recording_studio_user_identities.rb"),
        "# existing\n"
      )
      generator.define_singleton_method(:destination_root) { dir }

      assert generator.send(:people_profiles_migration_exists?)
      assert generator.send(:identities_migration_exists?)
    end
  end
end
