# frozen_string_literal: true

require "test_helper"

class AdminIntegrationTest < Minitest::Test
  def test_users_definitions_are_sitewide_and_read_only
    screen = RecordingStudioUser::Admin::UsersScreen
    section = RecordingStudioUser::Admin::UsersSection

    assert_equal "users", screen.key
    assert_equal :site, screen.blast_radius
    assert_equal :site, section.blast_radius
    assert_equal %i[name email time_zone created_at], screen.table_value.columns.map(&:key)
    assert_empty screen.table_value.actions
    refute_includes screen.table_value.columns.map(&:key), :admin
  end

  def test_total_users_widget_links_to_the_users_screen
    routes = Object.new
    routes.define_singleton_method(:screen_path) { |key| "/admin/screens/#{key}" }
    context = RecordingStudioAdmin::Context.new(routes: routes)
    user_class = Class.new
    user_class.define_singleton_method(:count) { 42 }
    original_user_model = RecordingStudioUser.configuration.user_model
    RecordingStudioUser.const_set(:WidgetTestUser, user_class)
    RecordingStudioUser.configuration.user_model = "RecordingStudioUser::WidgetTestUser"

    widget = RecordingStudioUser::Admin::TotalUsersWidget.resolve(context)

    assert_equal 42, widget.value
    assert_equal "/admin/screens/users", widget.link_to
  ensure
    RecordingStudioUser.configuration.user_model = original_user_model
    if RecordingStudioUser.const_defined?(:WidgetTestUser, false)
      RecordingStudioUser.send(:remove_const, :WidgetTestUser)
    end
  end

  def test_registration_is_repeatable_and_does_not_create_an_admin_root
    2.times { RecordingStudioUser.register_admin! }

    assert_equal RecordingStudioUser::Admin::UsersSection, RecordingStudioAdmin.section_for("users")
    assert_equal RecordingStudioUser::Admin::UsersScreen, RecordingStudioAdmin.screen_for("users")
    refute Object.const_defined?(:RecordingStudioUserAdminRoot)
  end
end
