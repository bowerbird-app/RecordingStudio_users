# frozen_string_literal: true

require "test_helper"

class UsersTncBoundaryTest < Minitest::Test
  def test_users_gem_extra_fields_soft_detects_tnc_without_depending_on_it
    extra_fields = File.read(
      File.expand_path("../app/views/recording_studio_user/auth/registrations/_extra_fields.html.erb", __dir__)
    )
    helper = File.read(
      File.expand_path("../app/helpers/recording_studio_user/auth_terms_notice_helper.rb", __dir__)
    )
    password = File.read(
      File.expand_path("../app/views/recording_studio_user/auth/registrations/password.html.erb", __dir__)
    )

    assert_includes extra_fields, "recording_studio_user_signup_terms_notice"
    assert_includes helper, "defined?(RecordingStudioTermsAndConditions)"
    assert_includes helper, "pending_published_list"
    refute_includes helper, "first_root_with_live_terms"
    assert_includes helper, "recording_studio_terms_continue_notice"
    engine = File.read(File.expand_path("../lib/recording_studio_user/engine.rb", __dir__))
    assert_includes engine, "prefer_signup_view_paths!"
    assert_includes engine, "prepend_view_path(users_views)"
    assert_includes engine, "prepend_view_path(host_views)"
    refute_match(/By continuing|agreed|checkbox/i, extra_fields)
    assert_includes password, 'render partial: "recording_studio_user/auth/registrations/extra_fields"'

    controller = File.read(
      File.expand_path("../app/controllers/recording_studio_user/auth/registrations_controller.rb", __dir__)
    )
    base = File.read(
      File.expand_path("../app/controllers/recording_studio_user/auth/base_controller.rb", __dir__)
    )
    concern = File.read(
      File.expand_path("../app/controllers/concerns/recording_studio_user/auth/signup_terms_acceptance.rb", __dir__)
    )
    assert_includes base, "prefer_host_then_users_signup_views"
    assert_includes base, "prepend_view_path(Rails.root.join(\"app/views\"))"
    assert_includes controller, "include SignupTermsAcceptance"
    assert_includes controller, "accept_pending_terms_on_signup!(resource)"
    assert_includes concern, "defined?(RecordingStudioTermsAndConditions::Gate)"
    assert_includes concern, '"source" => "continue_notice"'
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
    assert_includes dummy_gemfile, 'tag: "v0.8.1"'
    assert_includes dummy_gemfile, 'github: "bowerbird-app/RecordingStudio_publishable"'
    assert_includes dummy_gemfile, 'tag: "v0.4.4"'
    assert_includes dummy_gemfile, 'tag: "v0.1.207"'
    refute_match(/recording_studio_terms_and_conditions.*ref:/, dummy_gemfile)
    assert_includes dummy_lock, "tag: v0.8.1"
    assert_includes dummy_lock, "recording_studio_terms_and_conditions (0.8.0)"
    assert_includes dummy_lock, "dcc5713ee2f5e9ece6955a1b0601e06b845c23e1"
    assert_includes dummy_lock, "tag: v0.4.4"
    assert_includes dummy_lock, "recording_studio_publishable (0.4.0)"
    assert_includes dummy_lock, "flat_pack (0.1.207)"
  end
end
