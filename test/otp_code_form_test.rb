# frozen_string_literal: true

require "test_helper"

class OtpCodeFormTest < Minitest::Test
  def test_inline_form_is_the_code_box_without_the_auth_shell
    source = File.read(
      File.expand_path("../app/views/recording_studio_user/otp/_inline_code_form.html.erb", __dir__)
    )
    component = File.read(
      File.expand_path("../app/components/recording_studio_user/otp_code_form.rb", __dir__)
    )

    assert_includes source, "OtpCodeForm::FRAME_ID"
    assert_includes source, "signed_in_script"
    assert_includes source, "otp_direct_challenge_path"
    assert_includes source, "otp_direct_resend_path"
    assert_includes source, "use_different_email"
    refute_includes source, "auth/shell"
    refute_includes source, "auth_site_logo"
    refute_includes source, "FlatPack::PageTitle::Component"
    assert_includes component, "FRAME_ID = \"recording_studio_user_otp_inline\""
    assert_includes component, "recording_studio_user:signed_in"
  end

  def test_inline_answers_stay_on_the_existing_actions
    source = File.read(
      File.expand_path("../app/controllers/concerns/recording_studio_user/auth/inline_otp.rb", __dir__)
    )

    assert_includes source, "reject_foreign_origin!"
    assert_includes source, "head :forbidden"
    assert_includes source, "return_to"
    assert_includes source, "sign_in_user!"
    refute_includes source, "Access-Control-Allow-Origin"
  end
end
