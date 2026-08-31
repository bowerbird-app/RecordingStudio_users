# frozen_string_literal: true

require "test_helper"
require "generators/recording_studio_user/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  def test_tailwind_sources_name_the_engine_and_flatpack
    generator = RecordingStudioUser::Generators::InstallGenerator.new
    sources = generator.send(:tailwind_sources)

    assert(sources.any? { |line| line.include?("recording_studio_user") })
    assert(sources.any? { |line| line.include?("flatpack") })
  end

  def test_initializer_documents_route_load_timing
    initializer = File.read(
      File.expand_path(
        "../lib/generators/recording_studio_user/install/templates/recording_studio_user_initializer.rb", __dir__
      )
    )

    assert_includes initializer, "Route configuration must load before Rails draws routes."
    assert_includes initializer, "additional_profile_attributes"
    assert_includes initializer, "require_password_confirmation"
    assert_includes initializer, "omniauth_providers"
    assert_includes initializer, "omniauth_create_account"
    assert_includes initializer, "recording_studio_user/omniauth_callbacks"
    assert_includes initializer, "Rails.application.credentials.dig(:omniauth, :google_oauth2, :client_id)"
    refute_includes initializer, "config.login_title"
    assert_includes initializer, 'config.mount_path = "/recording_studio_users"'
    assert_includes initializer, 'config.profile_route_path = "profile"'
    assert_includes initializer, 'config.admin_route_path = "admin"'
  end

  def test_generator_source_does_not_create_users_or_devise
    generator = File.read(
      File.expand_path("../lib/generators/recording_studio_user/install/install_generator.rb", __dir__)
    )

    refute_includes generator, "rails generate devise"
    refute_includes generator, "create_table :users"
    refute_includes generator, "generate :model"
    refute_includes generator, "invoke \"recording_studio_user:admin\""
    assert_includes generator, "as: :recording_studio_users"
    assert_includes generator, "recording_studio_user:migrations"
    assert_includes generator, "Accessible and"
    assert_includes generator, "Attachable on Profile"
    assert_includes generator, "bootstrap_owner_access!"
    assert_includes generator, "recording_studio_attachable:install"
    refute_includes generator, "access_management_authorizer"
    refute_includes generator, "AccessCreationContext"
  end
end
