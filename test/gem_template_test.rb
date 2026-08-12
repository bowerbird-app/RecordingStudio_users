# frozen_string_literal: true

require "test_helper"

class RecordingStudioUserTest < Minitest::Test
  def test_version_and_engine_exist
    assert_match(/\A\d+\.\d+\.\d+\z/, RecordingStudioUser::VERSION)
    assert_kind_of Class, RecordingStudioUser::Engine
  end

  def test_profile_pages_use_a_page_title_without_an_outer_card
    profile_views = %w[show edit].map do |name|
      File.read(File.expand_path("../app/views/recording_studio_user/profiles/#{name}.html.erb", __dir__))
    end

    profile_views.each do |view|
      assert_includes view, "FlatPack::PageTitle::Component"
      refute_includes view, "FlatPack::Card::Component"
    end
  end

  def test_dummy_sidebar_links_the_mounted_profile_helper
    sidebar = File.read(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))

    assert_includes sidebar, 'label: "My profile"'
    assert_includes sidebar, "recording_studio_users.profile_path"
  end
end
