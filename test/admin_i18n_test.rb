# frozen_string_literal: true

require "test_helper"

class AdminI18nTest < Minitest::Test
  Copy = RecordingStudioUser::Copy

  def test_admin_chrome_keys_resolve_to_literal_english
    I18n.with_locale(:en) do
      assert_equal "Users", Copy.t("admin.section.title", default: "Users")
      assert_equal "Users admin", Copy.t("admin.section.link", default: "Users admin")
      assert_equal "Users", Copy.t("admin.screen.title", default: "Users")
      assert_equal "Users over time", Copy.t("admin.screen.chart_title", default: "Users over time")
      assert_equal "Users", Copy.t("admin.screen.series_users", default: "Users")
      assert_equal "Total users", Copy.t("admin.widget.total_users", default: "Total users")
      assert_equal "Name", Copy.t("admin.section.columns.name", default: "Name")
      assert_equal "Email", Copy.t("admin.section.columns.email", default: "Email")
      assert_equal "Created at", Copy.t("admin.section.columns.created_at", default: "Created at")
    end
  end

  def test_admin_source_calls_copy_for_titles_and_keeps_subtitle_and_columns_literal
    admin = File.read(File.expand_path("../lib/recording_studio_user/admin.rb", __dir__))

    assert_includes admin, 'Copy.t("admin.section.title"'
    assert_includes admin, 'Copy.t("admin.section.link"'
    assert_includes admin, 'Copy.t("admin.screen.title"'
    assert_includes admin, 'Copy.t("admin.screen.chart_title"'
    assert_includes admin, 'Copy.t("admin.screen.series_users"'
    assert_includes admin, 'Copy.t("admin.widget.total_users"'
    assert_includes admin, 'subtitle "Review sitewide user accounts"'
    assert_includes admin, 'title: "Name"'
    assert_includes admin, 'title: "Email"'
    assert_includes admin, 'title: "Created at"'
    refute_includes admin, 'title "Users"'
    refute_includes admin, 'text: "Users admin"'
    refute_includes admin, 'title "Total users"'
  end
end
