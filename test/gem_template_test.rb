# frozen_string_literal: true

require "test_helper"

class RecordingStudioUserTest < Minitest::Test
  def test_version_and_engine_exist
    assert_equal "0.25.1", RecordingStudioUser::VERSION
    assert_kind_of Class, RecordingStudioUser::Engine
    RecordingStudioUser::Engine.load_view_helpers!
    assert defined?(RecordingStudioUser::OmniauthHelper)
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
    assert_includes continue_partial, "recording_studio_user.omniauth.continue_with"
    assert_includes continue_partial, "form_with"
    assert_includes continue_partial, "FlatPack::Button::Component"
    assert_includes continue_partial, 't("recording_studio_user.omniauth.or")'
    refute File.exist?(
      File.expand_path("../app/views/recording_studio_user/omniauth/_continue_with_google.html.erb", __dir__)
    )

    assert_includes sign_in_methods, "FlatPack::List::Component"
    assert_includes sign_in_methods, "FlatPack::Card::Component"
    assert_includes sign_in_methods, "recording_studio_user.omniauth.connect"
    assert_includes sign_in_methods, "recording_studio_user.omniauth.disconnect"
    assert_includes sign_in_methods, "form_with"
    assert_includes sign_in_methods, "!items-center"
    assert_includes sign_in_methods, "inline-flex items-center"
    assert_includes profile_show, "sign_in_methods_profile_path"
    refute_includes profile_edit, "sign_in_methods_profile_path"
    assert_includes profile_edit, "recording_studio_user.profile.subtitle_with_language"
    assert_includes profile_edit, "recording_studio_user.profile.subtitle"
    assert_includes profile_edit, "profile_locale_allowlisted?"
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
    assert_includes edit, "recording_studio_user.profile.subtitle_with_language"
    assert_includes edit, "profile_locale_allowlisted?"
    assert_includes edit, 't("recording_studio_user.profile.language")'
    assert_includes edit, 'name: "user[locale]"'
    assert_includes edit, "placeholder: false"
    assert_includes show, "profile_language_name(@profile)"
    assert_includes edit, "FlatPack::Grid::Component.new(cols: 2)"
    assert_includes edit, %(class="mb-8")
    refute_includes edit, %(class="mb-16")
    refute_includes edit, "space-y-8"
    refute_includes edit, "icon_only"
    refute_includes edit, "camera"
    refute_includes edit, "FlatPack::ButtonGroup::Component"
    assert_includes edit, "FlatPack::Button::Component"
    assert_includes edit, "recording_studio_user.profile.update"
    assert_includes edit, "recording_studio_user.profile.cancel"
    assert_includes edit, "FlatPack::TextInput::Component"
    assert_includes edit, "FlatPack::Select::Component"
  end

  def test_gemfiles_pin_attachable_v0150_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_attachable"'
      assert_includes contents, 'tag: "v0.15.0"'
      refute_includes contents, 'tag: "v0.13.0"'
      refute_includes contents, 'tag: "v0.7.1"'
      refute_includes contents, 'RecordingStudio_attachable", tag: "v0.5.0"'
      refute_includes contents, "62c2f944d1ed206c84c80275851db0aee8e3306a"
      refute_includes contents, "cursor/file-only-replace-path-a5db"
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v0.15.0"
      assert_includes lock, "0140c73d2cce6a5bdbdc8825ff496c42f8e260c3"
      assert_includes lock, "recording_studio_attachable (0.15.0)"
      refute_includes lock, "recording_studio_attachable (0.13.0)"
      refute_includes lock, "8457c5681d9d3742d2b272082d62eecd91dd1102"
      refute_includes lock, "tag: v0.7.1"
      refute_includes lock, "recording_studio_attachable (0.5.0)"
      refute_includes lock, "62c2f944d1ed206c84c80275851db0aee8e3306a"
      refute_includes lock, "cursor/file-only-replace-path-a5db"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio_attachable", "~> 0.7"'
  end

  def test_gemfiles_pin_cache_v050_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_cache"'
      assert_includes contents, 'tag: "v0.5.0"'
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_cache.git"
      assert_includes lock, "tag: v0.5.0"
      assert_includes lock, "ffadfbd2a804104e1146c835aaf1bdb8068596ff"
      assert_includes lock, "recording_studio_cache (0.5.0)"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio_cache", "~> 0.5"'
  end

  def test_gemfiles_pin_accessible_v0180_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_accessible"'
      assert_includes contents, 'tag: "v0.18.0"'
      refute_includes contents, 'RecordingStudio_accessible", tag: "v0.17.0"'
      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_trashable"'
      assert_includes contents, 'tag: "v0.11.0"'
      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_metrics"'
      assert_includes contents, "require: false"
    end
    assert_includes File.read(File.expand_path("../Gemfile", __dir__)), 'tag: "v0.5.0"'
    assert_includes File.read(File.expand_path("dummy/Gemfile", __dir__)), 'tag: "v0.3.1"'

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v0.18.0"
      assert_includes lock, "2cd0a0117a9018cf3a8374823b5bf58578fa6eb9"
      assert_includes lock, "recording_studio_accessible (0.18.0)"
      refute_includes lock, "recording_studio_accessible (0.17.0)"
      refute_includes lock, "226c6a92472f6ddf1fabcb27ea52ef6a23e53f87"
      assert_includes lock, "recording_studio_trashable (0.11.0)"
    end
    root_lock = File.read(File.expand_path("../Gemfile.lock", __dir__))
    dummy_lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))
    assert_includes root_lock, "tag: v0.5.0"
    assert_includes root_lock, "b3ff62dbee7e4e1107e3e41cdae7b2481893ca51"
    assert_includes dummy_lock, "tag: v0.3.1"
    assert_includes dummy_lock, "a6cad79bcd2a82473db7b140cebdc1cc5e428d80"
    refute_includes root_lock, "b992b5d3a5ef0b5a96c98a2e1410810d7d872f20"

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio_accessible", "~> 0.11"'
    assert_includes gemspec, '"recording_studio_metrics", ">= 0.3", "< 1.0"'
  end

  def test_gemfiles_pin_recording_studio_v470_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'github: "bowerbird-app/RecordingStudio", tag: "v4.7.0"'
      refute_includes contents, 'RecordingStudio", tag: "v4.6.0"'
      refute_includes contents, 'RecordingStudio", tag: "v4.5.0"'
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v4.7.0"
      assert_includes lock, "613501164c57b6f0bf6e8e356d593b1e5c151368"
      assert_includes lock, "recording_studio (4.7.0)"
      refute_includes lock, "recording_studio (4.6.0)"
      refute_includes lock, "a6e42617e16647d91ddb70748e41774577f17b6c"
      refute_includes lock, "recording_studio (4.5.0)"
      refute_includes lock, "b34e59cbd4f56fbc76cf16965d4acda5aea60310"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio", "~> 4.2"'
  end

  def test_dummy_gemfile_pins_root_switchable_v090_tag
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.9.0"'
    refute_includes gemfile, 'RecordingStudio_root_switchable", tag: "v0.8.0"'
    refute_includes gemfile, 'RecordingStudio_root_switchable", tag: "v0.6.0"'
    assert_includes lock, "tag: v0.9.0"
    assert_includes lock, "9cc759ea3290724f349269a437a5e284ddd4b30a"
    assert_includes lock, "recording_studio_root_switchable (0.9.0)"
    refute_includes lock, "recording_studio_root_switchable (0.8.0)"
    refute_includes lock, "6f4ebe13d8021cc2097d4d93ab89d0dfb03e2c8c"
    refute_includes lock, "recording_studio_root_switchable (0.6.0)"
    refute_includes lock, "78ea1ad2b7705260fb07144ac32e7604b77090ab"
  end

  def test_root_gemfile_pins_admin_v230_and_flatpack_v01213
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))
    lock = File.read(File.expand_path("../Gemfile.lock", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_admin"'
    assert_includes gemfile, 'tag: "v2.3.0"'
    refute_includes gemfile, 'tag: "v2.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable"'
    assert_includes gemfile, 'tag: "v0.11.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics"'
    assert_includes gemfile, 'tag: "v0.5.0"'
    assert_includes gemfile, "require: false"
    assert_includes gemfile, 'gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.213"'
    assert_includes lock, "tag: v2.3.0"
    assert_includes lock, "d60442993f33ba358edc6a0fb51538c714aa9479"
    refute_includes lock, "recording_studio_admin (2.2.0)"
    refute_includes lock, "3568969c82cd393fce38c2f788785fa42aa188bc"
    assert_includes lock, "tag: v0.1.213"
    assert_includes lock, "flat_pack (0.1.213)"
    assert_includes lock, "9606a6f24717e8f98c22c73e7ed40b30523fdd3f"
    assert_includes lock, "recording_studio_admin (2.3.0)"
    assert_includes lock, "recording_studio_trashable (0.11.0)"
    assert_includes lock, "436cbb838e9d30b7a91b6d25c74fb3b749e8afe5"
    assert_includes lock, "tag: v0.5.0"
    assert_includes lock, "b3ff62dbee7e4e1107e3e41cdae7b2481893ca51"
    refute_includes lock, "b992b5d3a5ef0b5a96c98a2e1410810d7d872f20"

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"flat_pack", ">= 0.1.144"'
    assert_includes gemspec, '"recording_studio_admin", "~> 2.0"'
  end

  def test_dummy_gemfile_pins_admin_v230_and_flatpack_v01213
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_admin"'
    assert_includes gemfile, 'tag: "v2.3.0"'
    refute_includes gemfile, 'tag: "v2.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable"'
    assert_includes gemfile, 'tag: "v0.11.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics"'
    assert_includes gemfile, 'tag: "v0.3.1"'
    assert_includes gemfile, "require: false"
    assert_includes gemfile, 'gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.213"'
    assert_includes lock, "tag: v2.3.0"
    assert_includes lock, "d60442993f33ba358edc6a0fb51538c714aa9479"
    refute_includes lock, "recording_studio_admin (2.2.0)"
    refute_includes lock, "3568969c82cd393fce38c2f788785fa42aa188bc"
    assert_includes lock, "tag: v0.1.213"
    assert_includes lock, "flat_pack (0.1.213)"
    assert_includes lock, "recording_studio_admin (2.3.0)"
    assert_includes lock, "recording_studio_trashable (0.11.0)"
    assert_includes lock, "436cbb838e9d30b7a91b6d25c74fb3b749e8afe5"
    assert_includes lock, "tag: v0.3.1"
    assert_includes lock, "a6cad79bcd2a82473db7b140cebdc1cc5e428d80"
    refute_includes lock, "b992b5d3a5ef0b5a96c98a2e1410810d7d872f20"
  end

  def test_dummy_gemfile_pins_notifications_v070_tag
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_notifications"'
    assert_includes gemfile, 'tag: "v0.7.0"'
    refute_includes gemfile, 'path: "../../vendor/recording_studio_notifications"'
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_notifications.git"
    assert_includes lock, "tag: v0.7.0"
    assert_includes lock, "6fd2a4e01dd1e5a7c1cbce340152eae9e65bf8f6"
    assert_includes lock, "recording_studio_notifications (0.7.0)"
    refute_includes lock, "recording_studio_notifications (0.3.0)"
    refute_match(
      %r{^PATH\n  remote: \.\./\.\./vendor/recording_studio_notifications\n}m,
      lock
    )
  end

  def test_dummy_gemfile_pins_api_v0110_tag
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemfile,
                    'github: "bowerbird-app/RecordingStudio_api", tag: "v0.11.0"'
    refute_includes gemfile, "cursor/recordable-metrics-hook-0fe9"
    refute_includes gemfile, 'RecordingStudio_api", tag: "v0.7.0"'
    refute_includes gemfile, 'RecordingStudio_api", tag: "v0.6.7"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable"'
    assert_includes gemfile, 'tag: "v0.11.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics"'
    assert_includes gemfile, 'tag: "v0.3.1"'
    assert_includes gemfile, "require: false"
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_api.git"
    assert_includes lock, "tag: v0.11.0"
    assert_includes lock, "8a1aec37f97a52fa7749a7b02f7014030a39ac0a"
    assert_includes lock, "recording_studio_api (0.11.0)"
    refute_includes lock, "branch: cursor/recordable-metrics-hook-0fe9"
    refute_includes lock, "recording_studio_api (0.7.0)"
    refute_includes lock, "recording_studio_api (0.6.7)"
    assert_includes lock, "recording_studio_trashable (0.11.0)"
    assert_includes lock, "tag: v0.3.1"
    assert_includes lock, "a6cad79bcd2a82473db7b140cebdc1cc5e428d80"
    refute_includes lock, "b992b5d3a5ef0b5a96c98a2e1410810d7d872f20"
  end

  def test_dummy_gemfile_pins_mcp_v0170_tag
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_mcp"'
    assert_includes gemfile, 'tag: "v0.17.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_Oauth"'
    assert_includes gemfile, 'tag: "v0.12.2"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_site_settings"'
    assert_includes gemfile, 'tag: "v0.2.1"'
    refute_includes gemfile, 'path: "../../vendor/recording_studio_site_settings"'
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_mcp.git"
    assert_includes lock, "tag: v0.17.0"
    assert_includes lock, "ffa3066b91bd700f2aaf608871b492d4509bebbc"
    assert_includes lock, "recording_studio_mcp (0.17.0)"
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_Oauth.git"
    assert_includes lock, "tag: v0.12.2"
    assert_includes lock, "4b2e7a9ffc8df00c6a5eaa66b4f79f3a3ab286e2"
    assert_includes lock, "recording_studio_oauth (0.12.2)"
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_site_settings.git"
    assert_includes lock, "tag: v0.2.1"
    assert_includes lock, "db3f7d6cad9385021de99e8c026091bda51edaa9"
    assert_includes lock, "recording_studio_site_settings (0.2.0)"
    refute_includes lock, "remote: ../../vendor/recording_studio_site_settings"
  end

  def test_dummy_default_layout_head_sets_rounded_on_html
    head = File.read(File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__))

    assert_includes head, 'document.documentElement.setAttribute("data-theme", "rounded")'
    assert_includes head, 'stylesheet_link_tag "flat_pack/application"'
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
    assert_includes importmap, "RecordingStudioTermsAndConditions::Engine.root.join"
    assert_includes importmap, 'under: "controllers/recording_studio_terms_and_conditions"'
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

  def test_dummy_omniauth_placeholders_do_not_require_a_master_key
    initializer = File.read(
      File.expand_path("dummy/config/initializers/recording_studio_user.rb", __dir__)
    )

    assert_includes initializer, "providers_from_credentials"
    assert_includes initializer, "Dummy::OmniauthFallbacks.providers"
    assert_includes initializer, "google_oauth2:"
    assert_includes initializer, "microsoft_graph:"
    assert_includes initializer, "apple:"
    assert_includes initializer, "linkedin:"
    assert_includes initializer, "instagram:"
    assert_includes initializer, "client_id: PLACEHOLDER"
    assert_includes initializer, "Rails.env.test?"
    refute_includes initializer, "ENV["
    refute_includes initializer, "config.omniauth_providers = {}"
  end
end
