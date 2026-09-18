# frozen_string_literal: true

require "test_helper"

class AuthSiteLogoHelperTest < Minitest::Test
  def test_unsigned_auth_logo_uses_blob_path_not_preview
    helper = File.read(
      File.expand_path("../app/helpers/recording_studio_user/auth_site_logo_helper.rb", __dir__)
    )

    assert_includes helper, "wide_logo_for"
    assert_includes helper, "rails_blob_path"
    refute_includes helper, "preview_url"
    refute_includes helper, "recording_studio_site_wide_logo"
  end
end
