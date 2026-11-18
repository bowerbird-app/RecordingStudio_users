# frozen_string_literal: true

require "test_helper"

class UsersTncBoundaryTest < Minitest::Test
  COUPLING_NEEDLES = %w[
    RecordingStudioTermsAndConditions
    recording_studio_terms_and_conditions
    accept_terms
    prefer_signup_view_paths
    AuthTermsNoticeHelper
    SignupTermsAcceptance
  ].freeze

  def test_users_gem_does_not_couple_to_terms
    root = File.expand_path("..", __dir__)
    offenders = coupled_files(root).map { |path| path.delete_prefix("#{root}/") }

    assert_empty offenders
    notices = File.read(File.expand_path("../app/views/recording_studio_user/auth/_signup_notices.html.erb", __dir__))
    assert_includes notices, "signup_notice_partials"
    refute_match(/checkbox/i, notices)
  end

  def test_production_users_does_not_depend_on_tnc
    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    root_gemfile = File.read(File.expand_path("../Gemfile", __dir__))
    root_lock = File.read(File.expand_path("../Gemfile.lock", __dir__))

    refute_includes gemspec, "recording_studio_terms_and_conditions"
    refute_includes gemspec, "recording_studio_publishable"
    refute_includes root_gemfile, "recording_studio_terms_and_conditions"
    refute_includes root_lock, "recording_studio_terms_and_conditions"
  end

  def test_dummy_pins_released_tnc_tag
    dummy_gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    dummy_lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes dummy_gemfile, 'github: "bowerbird-app/RecordingStudio_terms_and_conditions"'
    assert_includes dummy_gemfile, 'tag: "v0.22.0"'
    assert_includes dummy_gemfile, 'github: "bowerbird-app/RecordingStudio_publishable"'
    assert_includes dummy_gemfile, 'tag: "v1.1.0"'
    assert_includes dummy_gemfile, 'tag: "v0.1.377"'
    refute_match(/recording_studio_terms_and_conditions.*ref:/, dummy_gemfile)
    assert_includes dummy_lock, "tag: v0.22.0"
    assert_includes dummy_lock, "recording_studio_terms_and_conditions (0.22.0)"
    assert_includes dummy_lock, "1d02a1340aad6710b4cad82522f732bd9c632759"
    assert_includes dummy_lock, "tag: v1.1.0"
    assert_includes dummy_lock, "recording_studio_publishable (1.1.0)"
    assert_includes dummy_lock, "a98f8d8a2303cc3dc5b197a45df7ece5bd46d906"
    refute_includes dummy_lock, "recording_studio_publishable (0.6.0)"
    refute_includes dummy_lock, "6e7da3c8a9359dfcde7a177d29a49886f85fdbf8"
    assert_includes dummy_lock, "flat_pack (0.1.377)"
  end

  private

  def coupled_files(root)
    Dir[File.join(root, "{app,lib,config}/**/*.{rb,erb,yml}")].select do |path|
      coupled?(File.read(path))
    end
  end

  def coupled?(source)
    COUPLING_NEEDLES.any? { |needle| source.include?(needle) }
  end
end
