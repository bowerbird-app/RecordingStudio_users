# frozen_string_literal: true

require "test_helper"
require "action_view"
require "fileutils"
require "tmpdir"

class SignupNoticePartialsTest < Minitest::Test
  def setup
    @original = RecordingStudioUser.config.signup_notice_partials.dup
  end

  def teardown
    RecordingStudioUser.config.signup_notice_partials = @original
  end

  def test_renders_nothing_by_default
    RecordingStudioUser.config.signup_notice_partials = []

    assert_equal "", render_notices.strip
  end

  def test_renders_configured_partials_in_order
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "_alpha.html.erb"), "ALPHA")
      File.write(File.join(dir, "_beta.html.erb"), "BETA")
      RecordingStudioUser.config.signup_notice_partials = %w[alpha beta]

      html = render_notices(dir)

      assert_includes html, "ALPHA"
      assert_includes html, "BETA"
      assert_operator html.index("ALPHA"), :<, html.index("BETA")
    end
  end

  def test_auth_forms_render_the_notice_partial_and_have_no_terms_checkbox
    password = File.read(
      File.expand_path("../app/views/recording_studio_user/auth/registrations/password.html.erb", __dir__)
    )
    inline = File.read(
      File.expand_path("../app/views/recording_studio_user/otp/_inline_code_form.html.erb", __dir__)
    )
    notices = File.read(
      File.expand_path("../app/views/recording_studio_user/auth/_signup_notices.html.erb", __dir__)
    )

    assert_includes notices, "signup_notice_partials"
    assert_includes password, 'render partial: "recording_studio_user/auth/signup_notices"'
    assert_includes inline, 'render partial: "recording_studio_user/auth/signup_notices"'
    refute_includes password, "accept_terms"
    refute_includes inline, "accept_terms"
    refute_includes notices, "RecordingStudioTermsAndConditions"
    refute File.exist?(
      File.expand_path("../app/views/recording_studio_user/auth/registrations/_extra_fields.html.erb", __dir__)
    )
  end

  private

  def render_notices(extra = nil)
    paths = [File.expand_path("../app/views", __dir__)]
    paths.unshift(extra) if extra
    lookup = ActionView::LookupContext.new(paths)
    lookup.formats = [:html]
    view = ActionView::Base.with_empty_template_cache.new(lookup, {}, nil)
    view.render(partial: "recording_studio_user/auth/signup_notices")
  end
end
