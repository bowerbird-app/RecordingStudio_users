# frozen_string_literal: true

require "test_helper"

class RecordingStudioUserTest < Minitest::Test
  def test_version_and_engine_exist
    assert_match(/\A\d+\.\d+\.\d+\z/, RecordingStudioUser::VERSION)
    assert_kind_of Class, RecordingStudioUser::Engine
  end

  def test_omniauth_views_use_flatpack_without_restyling_profile_edit
    continue_partial = File.read(
      File.expand_path("../app/views/recording_studio_user/omniauth/_continue_with_providers.html.erb", __dir__)
    )
    sign_in_methods = File.read(
      File.expand_path("../app/views/recording_studio_user/sign_in_methods/show.html.erb", __dir__)
    )
    profile_show = File.read(
      File.expand_path("../app/views/recording_studio_user/profiles/show.html.erb", __dir__)
    )
    profile_edit = File.read(
      File.expand_path("../app/views/recording_studio_user/profiles/edit.html.erb", __dir__)
    )

    assert_includes continue_partial, "recording_studio_user_omniauth_provider_names"
    assert_includes continue_partial, "Continue with"
    assert_includes continue_partial, "form_with"
    assert_includes continue_partial, "FlatPack::Button::Component"
    assert_includes continue_partial, 'FlatPack::Divider::Component.new(label: "Or"'
    refute File.exist?(
      File.expand_path("../app/views/recording_studio_user/omniauth/_continue_with_google.html.erb", __dir__)
    )

    assert_includes sign_in_methods, "FlatPack::List::Component"
    assert_includes sign_in_methods, "FlatPack::Card::Component"
    assert_includes sign_in_methods, 'text: "Connect"'
    assert_includes sign_in_methods, 'text: "Disconnect"'
    assert_includes sign_in_methods, "form_with"
    assert_includes sign_in_methods, "!items-center"
    assert_includes sign_in_methods, "inline-flex items-center"
    assert_includes profile_show, "sign_in_methods_profile_path"
    refute_includes profile_edit, "sign_in_methods_profile_path"
    assert_includes profile_edit, "Change your name, time zone, or photo."
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
    refute_includes avatar, "render_attachment_image_slot"
    refute_includes avatar, "render_attachment_file_button"
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
    refute_includes show, "render_attachment_image_slot"
    refute_includes show, "render_attachment_file_button"
    refute_includes show, 'turbo_frame_tag "profile-photo"'
    refute_includes show, "attachment-chrome-image_slot"
    refute_includes show, "file_field_tag"
    refute_includes show, "photo_profile_path"
    refute_includes show, "Tidy up"
    refute_includes edit, "The photo lives here too."
    refute_includes edit, 'render "photo"'
    refute_includes edit, "render_parent_attachment"
    refute_includes edit, "render_attachment_image_slot"
    assert_includes edit, 'turbo_frame_tag "profile-photo"'
    assert_includes edit, "attachment_preview_url(@profile_recording, variant: :square_med)"
    assert_includes edit, "render_attachment_file_button(@profile_recording, return_to: edit_profile_path)"
    assert_includes edit, "size: :\"2xl\""
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

  def test_gemfiles_pin_attachable_v050_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_attachable"'
      assert_includes contents, 'tag: "v0.5.0"'
      refute_includes contents, "62c2f944d1ed206c84c80275851db0aee8e3306a"
      refute_includes contents, "cursor/file-only-replace-path-a5db"
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v0.5.0"
      # Annotated tag object; peels to commit 76c3b234e392df823013a36f2d8d1a6b57c951f0
      assert_includes lock, "542777b2557ea235050fd4f42753653df90fe957"
      assert_includes lock, "recording_studio_attachable (0.5.0)"
      refute_includes lock, "62c2f944d1ed206c84c80275851db0aee8e3306a"
      refute_includes lock, "cursor/file-only-replace-path-a5db"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio_attachable", "~> 0.5.0"'
  end

  def test_gemfiles_pin_flatpack_v0143
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      assert_includes File.read(gemfile), 'gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.143"'
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v0.1.143"
      assert_includes lock, "flat_pack (0.1.143)"
      assert_includes lock, "3654913a87f3d72556223b81e0d8140a292e3c2e"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"flat_pack", "~> 0.1.143"'
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
    assert_includes sidebar, 'text: "Letters"'
    assert_includes sidebar, "letter_opener_web.letters_path"
    assert_includes sidebar, 'text: "Notifications"'
    assert_includes sidebar, "recording_studio_notifications.notifications_path"
    assert_includes sidebar, 'text: "Notification settings"'
    assert_includes sidebar, "recording_studio_notifications.settings_path"
    assert_includes sidebar, 'text: "Push devices"'
    assert_includes sidebar, "recording_studio_notifications_push.devices_path"
  end

  def test_dummy_importmap_pins_recording_studio_admin_controllers
    importmap = File.read(File.expand_path("dummy/config/importmap.rb", __dir__))

    assert_includes importmap, "RecordingStudioAdmin::Engine.root.join"
    assert_includes importmap, 'under: "controllers/recording_studio_admin"'
    assert_includes importmap, 'to: "recording_studio_admin/controllers"'
    assert_includes importmap, 'pin "@rails/activestorage"'
    assert_includes importmap, 'under: "controllers/recording_studio_attachable"'
  end

  def test_dummy_eagerly_loads_notifications_stimulus_controllers
    controllers = File.read(File.expand_path("dummy/app/javascript/controllers/index.js", __dir__))

    assert_includes controllers, 'eagerLoadControllersFrom("controllers/recording_studio_notifications", application)'
    assert_includes controllers,
                    'eagerLoadControllersFrom("controllers/recording_studio_notifications_push", application)'
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
