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

  def test_generator_skips_when_the_host_already_has_the_migration
    generator = RecordingStudioUser::Generators::MigrationsGenerator.new
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      File.write(
        File.join(dir, "db/migrate/20260821000000_create_recording_studio_user_people_and_profiles.rb"),
        "# existing\n"
      )
      generator.define_singleton_method(:destination_root) { dir }

      assert generator.send(:migration_already_exists?, "create_recording_studio_user_people_and_profiles")
    end
  end

  def test_authentication_method_migration_template
    template = File.read(
      File.expand_path(
        "../lib/generators/recording_studio_user/migrations/templates/add_authentication_method_to_users.rb.tt",
        __dir__
      )
    )

    assert_includes template, "authentication_method"
    assert_includes template, "users_authentication_method_check"
    assert_includes template, "UPDATE users SET authentication_method = 'password'"
  end

  def test_confirmable_backfill_migration_template
    template = File.read(
      File.expand_path(
        "../lib/generators/recording_studio_user/migrations/templates/add_devise_confirmable_to_users.rb.tt",
        __dir__
      )
    )

    assert_includes template, "confirmation_token"
    assert_includes template, "confirmed_at"
    assert_includes template, "UPDATE users SET confirmed_at = CURRENT_TIMESTAMP"
  end

  def test_otp_challenges_migration_template
    template = File.read(
      File.expand_path(
        "../lib/generators/recording_studio_user/migrations/templates/" \
        "create_recording_studio_user_otp_challenges.rb.tt",
        __dir__
      )
    )

    assert_includes template, "create_table :recording_studio_user_otp_challenges"
    assert_includes template, "code_digest"
    assert_includes template, "delivery_code_ciphertext"
    assert_includes template, "expires_at"
  end
end
