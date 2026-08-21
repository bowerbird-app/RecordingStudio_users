# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/recording_studio_users/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests RecordingStudioUsers::Generators::InstallGenerator
  destination File.expand_path("tmp/generator", __dir__)
  setup :prepare_destination

  def test_initializer_uses_accessible_and_host_root_callback
    run_generator ["--skip-devise"]

    assert_file "config/initializers/recording_studio_users.rb" do |content|
      assert_includes content, 'config.access_actor_types = ["User"]'
      assert_includes content, "config.root_creator"
      assert_includes content, "status: :requires_resolution"
      refute_includes content, "RECORDING_STUDIO_ACCESSIBLE_BOOTSTRAP_ADMIN"
    end
  end

  def test_mounts_engine
    run_generator ["--skip-devise"]

    assert_file "config/routes.rb", /mount RecordingStudioUsers::Engine/
  end
end
