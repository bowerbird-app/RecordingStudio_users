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
      assert_includes view, "recording_studio_page_nav"
      refute_includes view, "recording_studio_page_nav_right"
      refute_includes view, "recording_access_management_link"
      refute_includes view, "Manage access"
      assert_includes view, 'render "photo"'
    end

    show = profile_views.first
    edit = profile_views.last
    refute_includes show, "notice"
    refute_includes show, "flash["
    refute_includes show, "if notice"
    refute_includes show, "FlatPack::Alert::Component"
    refute_includes show, "Just you."
    assert_includes show, "Your name, email, and photo."
    assert_includes show, "page_title.slot"
    refute_includes show, "Tidy up"
    refute_includes edit, "The photo lives here too."
    assert_includes edit, "Change your name, time zone, or photo."
    refute_includes edit, "FlatPack::Grid::Component"
    refute_includes edit, "FlatPack::ButtonGroup::Component"
    assert_includes edit, "FlatPack::Button::Component"
    assert_includes edit, "Update profile"
    assert_includes edit, "Cancel"
    assert_includes edit, "FlatPack::TextInput::Component"
    assert_includes edit, "FlatPack::Select::Component"
  end

  def test_dummy_default_layout_head_sets_rounded_on_html
    head = File.read(File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__))

    assert_includes head, 'document.documentElement.setAttribute("data-theme", "rounded")'
    refute_includes head, "recording_studio/default_layout"
  end

  def test_dummy_overrides_attachable_show_without_an_in_view_page_nav
    override = File.read(
      File.expand_path("dummy/app/views/recording_studio_attachable/attachments/show.html.erb", __dir__)
    )

    assert_includes override, "recording_studio_page_nav"
    refute_includes override, "recording_studio_page_nav_right"
    refute_includes override, "FlatPack::PageNav"
    refute_includes override, "recording_access_management_link"
    refute_includes override, "Manage access"
    assert_includes override, "FlatPack::PageTitle::Component"
    assert_includes override, "FlatPack::TextInput::Component"
  end

  def test_dummy_sidebar_links_the_mounted_profile_helper
    sidebar = File.read(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))

    assert_includes sidebar, 'text: "My profile"'
    assert_includes sidebar, "recording_studio_users.profile_path"
    refute_includes sidebar, "recording_studio_users.admin_path"
  end

  def test_dummy_importmap_pins_recording_studio_admin_controllers
    importmap = File.read(File.expand_path("dummy/config/importmap.rb", __dir__))

    assert_includes importmap, "RecordingStudioAdmin::Engine.root.join"
    assert_includes importmap, 'under: "controllers/recording_studio_admin"'
    assert_includes importmap, 'to: "recording_studio_admin/controllers"'
    assert_includes importmap, 'pin "@rails/activestorage"'
    assert_includes importmap, 'under: "controllers/recording_studio_attachable"'
  end

  def test_dummy_importmap_pins_flat_pack_controllers_for_stimulus
    importmap = File.read(File.expand_path("dummy/config/importmap.rb", __dir__))

    assert_includes importmap, 'under: "controllers/flat_pack"'
    assert_includes importmap, 'to: "flat_pack/controllers"'
    assert_includes importmap, 'pin "flat_pack/local_time"'
  end

  def test_dummy_application_loads_turbo_for_admin_frames
    importmap = File.read(File.expand_path("dummy/config/importmap.rb", __dir__))
    application = File.read(File.expand_path("dummy/app/javascript/application.js", __dir__))

    assert_includes importmap, 'pin "@hotwired/turbo-rails", to: "turbo.min.js"'
    assert_includes application, 'import "@hotwired/turbo-rails"'
    assert_includes application, 'import { initLocalTimes } from "flat_pack/local_time"'
    assert_includes application, 'import * as ActiveStorage from "@rails/activestorage"'
    assert_includes application, "ActiveStorage.start()"
  end

  def test_dummy_tailwind_imports_generated_gem_sources
    css = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))
    procfile = File.read(File.expand_path("dummy/Procfile.dev", __dir__))

    assert_includes css, '@import "./gem_sources.css"'
    assert_includes procfile, "tailwindcss:watch[always]"
  end
end
