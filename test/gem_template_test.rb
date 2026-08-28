# frozen_string_literal: true

require "test_helper"

class RecordingStudioUserTest < Minitest::Test
  def test_version_and_engine_exist
    assert_match(/\A\d+\.\d+\.\d+\z/, RecordingStudioUser::VERSION)
    assert_kind_of Class, RecordingStudioUser::Engine
  end

  def test_profile_pages_use_a_page_title_and_show_identity_card
    profile_views = %w[show edit].map do |name|
      File.read(File.expand_path("../app/views/recording_studio_user/profiles/#{name}.html.erb", __dir__))
    end

    profile_views.each do |view|
      assert_includes view, "FlatPack::PageTitle::Component"
      assert_includes view, "recording_studio_page_nav"
      refute_includes view, "recording_studio_page_nav_right"
      refute_includes view, "recording_access_management_link"
      refute_includes view, "Manage access"
    end

    avatar = File.read(File.expand_path("../app/views/recording_studio_user/profiles/_avatar.html.erb", __dir__))
    assert_includes avatar, "FlatPack::Avatar::Component"
    refute_includes avatar, "file_field_tag"
    refute_includes avatar, "photo_profile_path"
    refute_includes avatar, "render_parent_attachment"
    refute File.exist?(File.expand_path("../app/views/recording_studio_user/profiles/_photo.html.erb", __dir__))

    show = profile_views.first
    edit = profile_views.last
    refute_includes show, "notice"
    refute_includes show, "flash["
    refute_includes show, "if notice"
    refute_includes show, "FlatPack::Alert::Component"
    refute_includes show, "Just you."
    refute_includes show, "Your name, email, and photo."
    assert_includes show, "page_title.slot"
    assert_includes show, 'render "avatar"'
    assert_includes show, "FlatPack::Card::Component"
    assert_includes show, "style: :elevated"
    assert_equal 1, show.scan("FlatPack::Grid::Component").size
    assert_includes show, "FlatPack::Grid::Component.new(cols: 2)"
    refute_includes show, "align: :center"
    refute_includes show, "inline-flex"
    refute_includes show, "Cluster"
    refute_includes show, "<dt"
    refute_includes show, "Name"
    refute_includes show, "city"
    refute_includes show, "render_parent_attachment"
    refute_includes show, "file_field_tag"
    refute_includes show, "photo_profile_path"
    refute_includes show, "Tidy up"
    refute_includes edit, "The photo lives here too."
    refute_includes edit, 'render "photo"'
    assert_includes edit, "render_parent_attachment(@profile_recording,"
    assert_includes edit, "return_to: edit_profile_path, shape: :circle, size: :\"2xl\")"
    refute_includes edit, "FlatPack::Card::Component"
    assert_includes edit, "Change your name, time zone, or photo."
    assert_includes edit, "FlatPack::Grid::Component.new(cols: 2)"
    assert_includes edit, %(class="mb-8")
    refute_includes edit, %(class="mb-16")
    refute_includes edit, "space-y-8"
    refute_includes edit, "icon_only"
    refute_includes edit, "camera"
    refute_includes edit, "FlatPack::ButtonGroup::Component"
    assert_includes edit, "FlatPack::Button::Component"
    assert_includes edit, "Update profile"
    assert_includes edit, "Cancel"
    assert_includes edit, "FlatPack::TextInput::Component"
    assert_includes edit, "FlatPack::Select::Component"
  end

  def test_gemfiles_pin_attachable_parent_attachment_branch
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_attachable"'
      assert_includes contents, 'branch: "cursor/file-only-replace-path-a5db"'
      refute_includes contents, 'tag: "0.4.0"'
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      assert_includes File.read(lockfile), "1477cc9242f2cddb8ca5b955e9ca9833a8ab6b0a"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio_attachable", "~> 0.5"'
  end

  def test_gemfiles_pin_flatpack_two_xl_avatar
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      assert_includes File.read(gemfile), 'gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.135"'
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v0.1.135"
      assert_includes lock, "flat_pack (0.1.135)"
      assert_includes lock, "534ce32b29d0d1666c24d04e75485ddd57fa4e2f"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"flat_pack", "~> 0.1.135"'
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
