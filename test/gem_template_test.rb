# frozen_string_literal: true

require "test_helper"

class RecordingStudioUserTest < Minitest::Test
  def test_version_and_engine_exist
    assert_equal "0.26.0", RecordingStudioUser::VERSION
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

  def test_gemfiles_pin_attachable_v0220_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_attachable"'
      assert_includes contents, 'tag: "v0.22.0"'
      refute_includes contents, 'tag: "v0.15.0"'
      refute_includes contents, 'tag: "v0.13.0"'
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v0.22.0"
      assert_includes lock, "f25c30bc37301099b34a55f10fc0f5aff056f025"
      assert_includes lock, "recording_studio_attachable (0.22.0)"
      refute_includes lock, "recording_studio_attachable (0.15.0)"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio_attachable", "~> 0.7"'
  end

  def test_gemfiles_pin_cache_v051_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_cache"'
      assert_includes contents, 'tag: "v0.5.1"'
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_cache.git"
      assert_includes lock, "tag: v0.5.1"
      assert_includes lock, "711cb9cf7074a3dcbe9b96b628d830e93dd46a5b"
      assert_includes lock, "recording_studio_cache (0.5.0)"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio_cache", "~> 0.5"'
  end

  def test_gemfiles_pin_accessible_v0220_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_accessible"'
      assert_includes contents, 'tag: "v0.22.0"'
      refute_includes contents, 'RecordingStudio_accessible", tag: "v0.18.0"'
      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_trashable"'
      assert_includes contents, 'tag: "v0.12.0"'
      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_metrics"'
      assert_includes contents, 'tag: "v0.6.1"'
      assert_includes contents, "require: false"
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v0.22.0"
      assert_includes lock, "be0fe762c86ef871711c01de87bc0a7f4df7cc22"
      assert_includes lock, "recording_studio_accessible (0.22.0)"
      refute_includes lock, "recording_studio_accessible (0.18.0)"
      assert_includes lock, "tag: v0.12.0"
      assert_includes lock, "120c5874a2d57e21c435c0599ff6dfa56560b194"
      assert_includes lock, "recording_studio_trashable (0.12.0)"
      assert_includes lock, "tag: v0.6.1"
      assert_includes lock, "05e78289bbe3d9a90507c4cb4d7ba990edc57227"
      assert_includes lock, "recording_studio_metrics (0.6.1)"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio_accessible", "~> 0.11"'
    assert_includes gemspec, '"recording_studio_metrics", ">= 0.3", "< 1.0"'
    assert_includes gemspec, '"view_component", ">= 4.14", "< 5"'
  end

  def test_gemfiles_pin_recording_studio_v610_tag
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'github: "bowerbird-app/RecordingStudio", tag: "v6.1.0"'
      refute_includes contents, 'RecordingStudio", tag: "v4.7.0"'
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v6.1.0"
      assert_includes lock, "403521dddc141ddb12d1ed8d8b30bd4105a9d6f8"
      assert_includes lock, "recording_studio (6.1.0)"
      refute_includes lock, "recording_studio (4.7.0)"
      assert_includes lock, "view_component (4.19.0)"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"recording_studio", ">= 6.1.0"'
  end

  def test_dummy_gemfile_pins_root_switchable_v090_tag
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.9.0"'
    assert_includes lock, "tag: v0.9.0"
    assert_includes lock, "9cc759ea3290724f349269a437a5e284ddd4b30a"
    assert_includes lock, "recording_studio_root_switchable (0.9.0)"
  end

  def test_gemfiles_pin_admin_v270_and_flatpack_01319
    [File.expand_path("../Gemfile", __dir__), File.expand_path("dummy/Gemfile", __dir__)].each do |gemfile|
      contents = File.read(gemfile)

      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_admin"'
      assert_includes contents, 'tag: "v2.7.0"'
      refute_includes contents, 'tag: "v2.3.0"'
      assert_includes contents, 'github: "bowerbird-app/RecordingStudio_logs"'
      assert_includes contents, 'tag: "v0.7.0"'
      assert_includes contents, 'github: "bowerbird-app/flatpack"'
      assert_includes contents, 'ref: "1fcbafe94f8eb118f0a22182f63f5110fcc97a56"'
    end

    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      lock = File.read(lockfile)
      assert_includes lock, "tag: v2.7.0"
      assert_includes lock, "22ebcc771b7144c5929f8caee690de6a65145a65"
      assert_includes lock, "recording_studio_admin (2.7.0)"
      refute_includes lock, "recording_studio_admin (2.3.0)"
      assert_includes lock, "tag: v0.7.0"
      assert_includes lock, "3127366cfccc882b20a01f76811adc8c055e248d"
      assert_includes lock, "recording_studio_logs (0.7.0)"
      assert_includes lock, "ref: 1fcbafe94f8eb118f0a22182f63f5110fcc97a56"
      assert_includes lock, "flat_pack (0.1.319)"
    end

    gemspec = File.read(File.expand_path("../recording_studio_user.gemspec", __dir__))
    assert_includes gemspec, '"flat_pack", ">= 0.1.315"'
    assert_includes gemspec, '"recording_studio_admin", "~> 2.0"'
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
  end

  def test_dummy_gemfile_pins_api_v0160_tag
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_api", tag: "v0.16.0"'
    refute_includes gemfile, 'RecordingStudio_api", tag: "v0.11.0"'
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_api.git"
    assert_includes lock, "tag: v0.16.0"
    assert_includes lock, "62ef31dbc066fa877b5cb088607deb2ad20220ae"
    assert_includes lock, "recording_studio_api (0.16.0)"
    refute_includes lock, "recording_studio_api (0.11.0)"
  end

  def test_dummy_gemfile_pins_mcp_v0230_and_oauth_v0170
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    lock = File.read(File.expand_path("dummy/Gemfile.lock", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_mcp"'
    assert_includes gemfile, 'tag: "v0.23.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_Oauth"'
    assert_includes gemfile, 'tag: "v0.17.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_site_settings"'
    assert_includes gemfile, 'tag: "v0.2.1"'
    refute_includes gemfile, 'path: "../../vendor/recording_studio_site_settings"'
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_mcp.git"
    assert_includes lock, "tag: v0.23.0"
    assert_includes lock, "7ba176c08a7f27a42a410926cb9fb21c0522d679"
    assert_includes lock, "recording_studio_mcp (0.23.0)"
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_Oauth.git"
    assert_includes lock, "tag: v0.17.0"
    assert_includes lock, "86c48350fa1934dfe549f1a4f9a1870782f37d86"
    assert_includes lock, "recording_studio_oauth (0.17.0)"
    assert_includes lock, "remote: https://github.com/bowerbird-app/RecordingStudio_site_settings.git"
    assert_includes lock, "tag: v0.2.1"
    assert_includes lock, "db3f7d6cad9385021de99e8c026091bda51edaa9"
    assert_includes lock, "recording_studio_site_settings (0.2.0)"
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
