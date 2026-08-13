# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
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
  end
end
