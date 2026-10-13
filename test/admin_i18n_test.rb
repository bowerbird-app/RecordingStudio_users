# frozen_string_literal: true

require "test_helper"

class AdminI18nTest < Minitest::Test
  def test_admin_dsl_stays_main_literal_strings
    admin = File.read(File.expand_path("../lib/recording_studio_user/admin.rb", __dir__))

    assert_includes admin, 'title "Users"'
    assert_includes admin, 'subtitle "Review sitewide user accounts"'
    assert_includes admin, 'text: "Users admin"'
    assert_includes admin, 'title "Users over time"'
    assert_includes admin, 'name: "Users"'
    assert_includes admin, 'title "Total users"'
    assert_includes admin, 'title: "Name"'
    assert_includes admin, 'title: "Email"'
    assert_includes admin, 'title: "Created at"'

    refute_includes admin, "Copy.t"
    refute_includes admin, "Copy.legacy_t"
    refute_includes admin, "title {"
    refute_includes admin, "text: ->"
  end

  def test_engine_locales_do_not_ship_admin_keys
    en = File.read(File.expand_path("../config/locales/en.yml", __dir__))

    refute_match(/^\s+admin:\s*$/, en)
    refute_includes en, "Users admin"
    refute_includes en, "Users over time"
    refute_includes en, "Total users"
  end
end
