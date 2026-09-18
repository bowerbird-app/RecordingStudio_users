# frozen_string_literal: true

require "test_helper"

class AuthSiteLogoHelperTest < Minitest::Test
  def test_unsigned_auth_logo_uses_blob_path_not_preview
    helper = File.read(
      File.expand_path("../app/helpers/recording_studio_user/auth_site_logo_helper.rb", __dir__)
    )
    wide = File.read(
      File.expand_path("../app/views/recording_studio_user/auth/_wide_logo.html.erb", __dir__)
    )

    assert_includes helper, "wide_logo_for"
    assert_includes helper, "square_logo_for"
    assert_includes helper, "rails_blob_path"
    refute_includes helper, "preview_url"
    refute_includes helper, "recording_studio_site_wide_logo"
    refute_includes helper, "recording_studio_site_square_logo"
    assert_includes wide, "max-h-12"
    assert_includes wide, "max-w-full"
  end
end
