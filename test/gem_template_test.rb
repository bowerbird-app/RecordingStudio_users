# frozen_string_literal: true

require "test_helper"

class RecordingStudioUserTest < Minitest::Test
  def test_version_and_engine_exist
    assert_equal "0.43.0", RecordingStudioUser::VERSION
    assert_equal "recording_studio_user/code_sign_in", RecordingStudioUser::CodeSignInToken::PURPOSE
    assert_operator RecordingStudioUser::Services::OpenCodeSignIn, :<, RecordingStudio::Services::BaseService
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
    assert_includes continue_partial, "icon: button_icon"
    assert_includes continue_partial, 't("recording_studio_user.omniauth.or")'
    refute File.exist?(
      File.expand_path("../lib/recording_studio_user/flatpack_button_svg_icon.rb", __dir__)
    )
    refute defined?(RecordingStudioUser::FlatpackButtonSvgIcon)
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
      assert_includes view, "content_for :title"
      assert_includes view, "flat_pack_page_nav"
      refute_includes view, "FlatPack::PageTitle::Component"
      refute_includes view, "recording_studio_page_nav"
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
    assert_includes show, "register_page_nav"
    refute_includes show, "page_title.slot"
    assert_includes show, 'render "avatar"'
    assert_includes show, "FlatPack::Card::Component"
    assert_includes show, "shadow: :md"
    refute_includes show, "style: :elevated"
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
    assert_includes edit, 'id="profile-photo"'
    assert_includes edit, "FlatPack::ImageInput::Component"
    assert_includes edit, "attachment_preview_url(@profile_recording, variant: :square_med)"
    assert_includes edit, "profile_image_upload_data(@profile_recording)"
    assert_includes edit, 'name: "profile_image[file]"'
    assert_includes edit, "shape: :circle"
    assert_includes edit, "size: :\"2xl\""
    refute_includes edit, "render_attachment_file_button"
    refute_includes edit, "FlatPack::Avatar::Component"
    refute_includes edit, "FlatPack::Card::Component"
    assert_includes edit, "recording_studio_user.profile.subtitle_with_language"
    assert_includes edit, "profile_locale_allowlisted?"
    assert_includes edit, 't("recording_studio_user.profile.language")'
    assert_includes edit, 'name: "user[locale]"'
    assert_includes edit, "placeholder: false"
    assert_includes show, "profile_language_name(@profile)"
    assert_includes edit, "FlatPack::Grid::Component.new(cols: 2)"
    assert_includes edit, %(class="mb-8")
    assert_includes edit, "gap-3 pt-4"
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

  def test_gemfiles_pin_attachable_v0220_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      attachable = contents[/gem "recording_studio_attachable".*?tag: "v[\d.]+"/m]

      assert attachable, "expected an attachable GitHub pin"
      assert_includes attachable, 'gem "recording_studio_attachable", "~> 0.34"'
      assert_includes attachable, 'github: "bowerbird-app/RecordingStudio_attachable"'
      assert_includes attachable, 'tag: "v0.34.0"'
      refute_includes attachable, 'tag: "v0.15.0"'
      refute_includes attachable, 'tag: "v0.13.0"'
      refute_includes attachable, 'tag: "v0.31.0"'
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v0.34.0"
      assert_includes lock, "0286a1af890dbcbbf957c6342427b31abceb3d85"
      assert_includes lock, "recording_studio_attachable (0.34.0)"
      refute_includes lock, "recording_studio_attachable (0.15.0)"
      refute_includes lock, "recording_studio_attachable (0.31.0)"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio_attachable", ">= 0.31.0", "< 1"'
  end

  def test_gemfiles_pin_cache_for_suite_and_dummy
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))
    dummy_gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("../Gemfile.lock", __dir__))
    dummy_lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))
    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))

    assert_includes gemfile, 'gem "recording_studio_cache", "~> 0.8",'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_cache"'
    assert_includes gemfile, 'tag: "v0.8.0"'
    assert_includes dummy_gemfile, 'gem "recording_studio_cache", "~> 0.8",'
    assert_includes dummy_gemfile, 'github: "bowerbird-app/RecordingStudio_cache"'
    assert_includes dummy_gemfile, 'tag: "v0.8.0"'
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_cache.git"
    assert_includes lock, "tag: v0.8.0"
    assert_includes lock, "4b4e0587663cc9591a2b919ed326a61d29902e92"
    assert_includes lock, "recording_studio_cache (0.8.0)"
    assert_includes dummy_lock, "remote: https://github.com/bowerbird-app/RecordingStudio_cache.git"
    assert_includes dummy_lock, "tag: v0.8.0"
    assert_includes dummy_lock, "4b4e0587663cc9591a2b919ed326a61d29902e92"
    assert_includes dummy_lock, "recording_studio_cache (0.8.0)"
    assert_includes gemspec, '"recording_studio_cache", ">= 0.5", "< 1"'
  end

  def test_lockfiles_pin_rack_and_dummy_addressable_for_audit
    lock = File.read(File.expand_path("../Gemfile.lock", __dir__))
    dummy_lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes lock, "rack (3.2.8)"
    refute_includes lock, "rack (3.2.7)"
    assert_includes dummy_lock, "rack (3.2.8)"
    refute_includes dummy_lock, "rack (3.2.7)"
    assert_includes dummy_lock, "addressable (2.9.2)"
    refute_includes dummy_lock, "addressable (2.9.0)"
  end

  def test_gemfiles_pin_accessible_v0241_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      accessible_pin = [
        'gem "recording_studio_accessible", "~> 0.58",',
        'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.58.0"'
      ].join(" ")
      assert_includes contents, accessible_pin
      refute_includes contents, 'RecordingStudio_accessible", tag: "v0.18.0"'
      assert_includes contents, 'gem "recording_studio_trashable", "~> 1.3"'
      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_trashable"'
      assert_includes contents, 'tag: "v1.3.0"'
      assert_includes contents, 'gem "recording_studio_metrics", "~> 0.10"'
      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_metrics"'
      assert_includes contents, 'tag: "v0.10.0"'
      assert_includes contents, "require: false"
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v0.58.0"
      assert_includes lock, "b2a053a680c827e28dae377ccf8982c5872571f5"
      assert_includes lock, "recording_studio_accessible (0.58.0)"
      refute_includes lock, "recording_studio_accessible (0.18.0)"
      assert_includes lock, "tag: v1.3.0"
      assert_includes lock, "1d2b76db12720890769f3eca2885a45b54afd27b"
      assert_includes lock, "recording_studio_trashable (1.3.0)"
      assert_includes lock, "tag: v0.10.0"
      assert_includes lock, "782080ddda956dbe8b7c3f999a40bd74e37aabb3"
      assert_includes lock, "recording_studio_metrics (0.10.0)"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio_accessible", ">= 0.43.1", "< 1"'
    assert_includes gemspec, '"recording_studio_metrics", ">= 0.3", "< 1.0"'
    assert_includes gemspec, '"view_component", ">= 4.14", "< 5"'
  end

  def test_gemfiles_pin_recording_studio_for_suite_and_dummy
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))
    dummy_gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("../Gemfile.lock", __dir__))
    dummy_lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))
    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))

    studio_pin = [
      'gem "recording_studio", "~> 7.8",',
      'github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"'
    ].join(" ")
    assert_includes gemfile, studio_pin
    refute_includes gemfile, 'RecordingStudio", tag: "v4.7.0"'
    assert_includes dummy_gemfile, studio_pin
    refute_includes dummy_gemfile, 'RecordingStudio", tag: "v4.7.0"'
    assert_includes lock, "tag: v7.8.0"
    assert_includes lock, "65ce2d0198b37d14429d4189772d29a9ab0b39cf"
    assert_includes lock, "recording_studio (7.8.0)"
    refute_includes lock, "recording_studio (4.7.0)"
    assert_includes lock, "view_component (4.24.0)"
    assert_includes dummy_lock, "tag: v7.8.0"
    assert_includes dummy_lock, "65ce2d0198b37d14429d4189772d29a9ab0b39cf"
    assert_includes dummy_lock, "recording_studio (7.8.0)"
    refute_includes dummy_lock, "recording_studio (4.7.0)"
    assert_includes dummy_lock, "view_component (4.24.0)"
    assert_includes gemspec, '"recording_studio", ">= 7.1", "< 8.0"'
  end

  def test_dummy_gemfile_pins_root_switchable_v0114_tag
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    root_switchable_pin = [
      'gem "recording_studio_root_switchable", "~> 0.17",',
      'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.17.0"'
    ].join(" ")
    assert_includes gemfile, root_switchable_pin
    assert_includes lock, "tag: v0.17.0"
    assert_includes lock, "faee22073d96e4c4b1b7b1eca7b84573752694cf"
    assert_includes lock, "recording_studio_root_switchable (0.17.0)"
  end

  def test_gemfiles_pin_admin_v270_and_flatpack_01341
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'gem "recording_studio_admin", "~> 2.20"'
      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_admin"'
      assert_includes contents, 'tag: "v2.20.0"'
      refute_includes contents, 'tag: "v2.3.0"'
      assert_includes contents, 'gem "recording_studio_logs", "~> 0.9"'
      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_logs"'
      assert_includes contents, 'tag: "v0.9.0"'
      assert_includes contents, 'gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"'
      refute_includes contents, "d005941bf5a09a51582d5b7418fe5486738474eb"
      refute_includes contents, "d1206e7c515bff9c25c01a2f5c6399d208ba667e"
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v2.20.0"
      assert_includes lock, "060c1f40714d76e78aef0251cae3e5056cf0a663"
      assert_includes lock, "recording_studio_admin (2.20.0)"
      refute_includes lock, "recording_studio_admin (2.3.0)"
      assert_includes lock, "tag: v0.9.0"
      assert_includes lock, "bd39e2691f888af2d9a317553cd892a1b92428d1"
      assert_includes lock, "recording_studio_logs (0.9.0)"
      assert_includes lock, "tag: v0.2.0"
      assert_includes lock, "flat_pack (0.2.0)"
      assert_includes lock, "2286d0f8c494a67f7a71370d2987cfc435b0c430"
      refute_includes lock, "d005941bf5a09a51582d5b7418fe5486738474eb"
      refute_includes lock, "d1206e7c515bff9c25c01a2f5c6399d208ba667e"
      refute_includes lock, "flat_pack (0.1.377)"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"flat_pack", ">= 0.1.328"'
    assert_includes gemspec, '"recording_studio_admin", ">= 2.16.0", "< 3"'
  end

  def test_dummy_gemfile_pins_notifications_v0147_tag
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemfile, 'gem "recording_studio_notifications", "~> 0.21"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_notifications"'
    assert_includes gemfile, 'tag: "v0.21.0"'
    refute_includes gemfile, 'path: "../../vendor/recording_studio_notifications"'
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_notifications.git"
    assert_includes lock, "tag: v0.21.0"
    assert_includes lock, "5ffb03146e034ef2d95607fe70f12a862d7b9ead"
    assert_includes lock, "recording_studio_notifications (0.21.0)"
  end

  def test_ci_uses_recording_studio_user_test_database
    ci = File.read(File.expand_path("../.github/workflows/ci.yml", __dir__))

    assert_includes ci, "POSTGRES_DB: recording_studio_user_test"
    assert_includes ci, "postgres://postgres:postgres@localhost:5432/recording_studio_user_test"
    refute_includes ci, "gem_template_test"
  end

  def test_dummy_gemfile_pins_notifications_email_v051_tag
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_notifications_email"'
    assert_includes gemfile, 'tag: "v0.5.4"'
    refute_includes gemfile, 'path: "../../vendor/recording_studio_notifications_email"'
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_notifications_email.git"
    assert_includes lock, "tag: v0.5.4"
    assert_includes lock, "fe855a541eb4b18bce0170ef0964993a859c122e"
    assert_includes lock, "recording_studio_notifications_email (0.5.4)"
    refute_includes lock, "remote: ../../vendor/recording_studio_notifications_email"
  end

  def test_dummy_gemfile_pins_api_v0171_tag
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    api_pin = [
      'gem "recording_studio_api", "~> 1.21",',
      'github: "bowerbird-app/RecordingStudio_api", tag: "v1.21.2"'
    ].join(" ")
    assert_includes gemfile, api_pin
    refute_includes gemfile, 'RecordingStudio_api", tag: "v0.11.0"'
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_api.git"
    assert_includes lock, "tag: v1.21.2"
    assert_includes lock, "758371de7752a7893d1614e6ea477b2f71c30063"
    assert_includes lock, "recording_studio_api (1.21.2)"
    refute_includes lock, "recording_studio_api (0.11.0)"
    refute_includes lock, "recording_studio_api (1.21.3)"
  end

  def test_dummy_gemfile_pins_mcp_v0232_and_oauth_v0210
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_mcp"'
    assert_includes gemfile, 'tag: "v0.35.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_Oauth"'
    assert_includes gemfile, 'tag: "v0.25.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_site_settings"'
    assert_includes gemfile, 'tag: "v0.6.0"'
    refute_includes gemfile, 'path: "../../vendor/recording_studio_site_settings"'
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_mcp.git"
    assert_includes lock, "tag: v0.35.0"
    assert_includes lock, "d6d8bf95cd6239ce9c37617217a50433f56ffdd8"
    assert_includes lock, "recording_studio_mcp (0.35.0)"
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_Oauth.git"
    assert_includes lock, "tag: v0.25.0"
    assert_includes lock, "6e27672df0e6821f61a7fa2345b4cdb3f2eb5d6f"
    assert_includes lock, "recording_studio_oauth (0.25.0)"
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_site_settings.git"
    assert_includes lock, "tag: v0.6.0"
    assert_includes lock, "e967d9d73208638ad9369e830d925fc5fc8d1d1b"
    assert_includes lock, "recording_studio_site_settings (0.6.0)"
    refute_includes lock, "remote: ../../vendor/recording_studio_site_settings"
  end

  def test_dummy_default_layout_head_sets_rounded_on_html
    head = File.read(File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__))

    assert_includes head, 'document.documentElement.setAttribute("data-theme", "rounded")'
    refute_includes head, "stylesheet_link_tag"
    refute_includes head, "recording_studio/default_layout"
  end

  def test_dummy_overrides_attachable_show_without_an_in_view_page_nav
    override = File.read(
      File.expand_path("dummy/app/views/recording_studio_attachable/attachments/show.html.erb", __dir__)
    )

    assert_includes override, "flat_pack_page_nav"
    assert_includes override, "content_for :title"
    refute_includes override, "recording_studio_page_nav"
    refute_includes override, "recording_studio_page_nav_right"
    refute_includes override, "FlatPack::PageNav"
    refute_includes override, "FlatPack::PageTitle::Component"
    refute_includes override, "recording_access_management_link"
    refute_includes override, "Manage access"
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
