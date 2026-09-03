# frozen_string_literal: true

require "test_helper"

class RecordingStudioNotificationsPushTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.2.0", ::RecordingStudioNotificationsPush::VERSION
  end

  def test_importmap_preloads_push_devices_controller
    importmap = File.read(File.expand_path("../config/importmap.rb", __dir__))

    assert_includes importmap, "controllers/recording_studio_notifications_push/push_devices_controller"
    assert_includes importmap, "preload: true"
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioNotificationsPush::Engine
  end

  def test_gemspec_pins_dependencies
    gemspec = File.read(File.expand_path("../recording_studio_notifications_push.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_notifications", ">= 0.3.0", "< 1"'
    assert_includes gemspec, "RecordingStudio_notifications_push"
    assert_includes gemspec, "CHANGELOG.md"
  end

  def test_dummy_gemfile_pins_verified_github_sources
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.7.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_notifications"'
    assert_includes gemfile, "vendor/recording_studio_notifications_email"
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_PWA"'
    assert_includes gemfile, "cursor/pwa-service-worker-seam-453c"
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.133"'
  end

  def test_does_not_ship_template_capabilities_or_pages
    refute File.exist?(File.expand_path("../lib/recording_studio_notifications_push/capabilities/example.rb", __dir__))
    refute File.exist?(File.expand_path("../app/controllers/recording_studio_notifications_push/home_controller.rb",
                                        __dir__))
    pages = Dir[File.expand_path("../db/migrate/*pages*.rb", __dir__)]
    assert_empty pages
  end

  def test_dummy_app_uses_flatpack_sidebar_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "flat_pack_sidebar"
    refute_includes controller_source, "UsesDefaultLayout"
    assert File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    assert File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))
  end

  def test_product_readme_describes_push_channel
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "RecordingStudioNotificationsPush"
    assert_includes readme, ":push"
    assert_includes readme, "FIREBASE_SERVICE_ACCOUNT_JSON"
    assert_includes readme, "deliver_rollup"
    refute_includes readme, "ExampleService"
    refute_includes readme, "addon template"
  end

  def test_devices_view_and_service_worker_partial_exist
    assert File.exist?(
      File.expand_path("../app/views/recording_studio_notifications_push/devices/show.html.erb", __dir__)
    )
    assert File.exist?(
      File.expand_path("../app/views/recording_studio_notifications_push/_service_worker_push.js.erb", __dir__)
    )
    push_devices_js = File.read(
      File.expand_path(
        "../app/javascript/recording_studio_notifications_push/controllers/push_devices_controller.js",
        __dir__
      )
    )
    assert_includes push_devices_js, "serviceWorkerRegistration"
    assert_includes push_devices_js, "resolveServiceWorkerRegistration"
    assert_includes push_devices_js, "not mounted"
    assert_includes push_devices_js, "data-push-enable"
    assert_includes push_devices_js, "detectCurrentBrowser"
    assert_includes push_devices_js, "installedApp"
    assert_includes push_devices_js, "hideEnablePanel"
    assert_includes push_devices_js, "Enable on this device"
    assert_includes push_devices_js, "Enable on this browser"
    assert_includes push_devices_js, "chrome://settings/"
    assert_includes push_devices_js, "Sites can ask to send notifications"
    assert_includes push_devices_js, "Privacy, search, and services"
    assert_includes push_devices_js, "Site permissions → All sites"
    assert_includes push_devices_js, "Privacy & Security → Permissions"
    assert_includes push_devices_js, "Open Websites → Notifications"
    assert_includes push_devices_js, "Privacy & security → Site settings → Notifications"
    assert_includes push_devices_js, "Use iOS or iPadOS 16.4 or later"
    assert_includes push_devices_js, "Add to Home Screen"
    assert_includes push_devices_js, "select this web app’s name"
    assert_includes push_devices_js, '["Firefox", "Opera"].includes(browser)'
    assert_includes push_devices_js, "Open this site in Safari, Chrome, or Edge"
    assert_includes push_devices_js, "Notifications from apps and other senders"
    assert_includes push_devices_js, "Settings → Notifications → App notifications"
    assert_includes push_devices_js, "`${index + 1}. ${step}`"
    assert_includes push_devices_js, "helpTarget"
    assert_includes push_devices_js, "requestAnimationFrame(() => this.fillNotificationHelp())"
    refute_includes push_devices_js, "sitePermissionHelp"
    refute_includes push_devices_js, "Looks like"
    refute_includes push_devices_js, "Settings → Notifications → Safari"
    refute_includes push_devices_js, "Settings → Notifications → Chrome"

    sw_partial = File.read(
      File.expand_path("../app/views/recording_studio_notifications_push/_service_worker_push.js.erb", __dir__)
    )
    refute_includes sw_partial, "hasDisplayPayload"
    assert_includes sw_partial, "showNotification"
    assert_includes sw_partial, "/icon.png"
    assert_includes sw_partial, "absoluteAssetUrl"
    assert_includes sw_partial, "options.image"
    refute_includes sw_partial, "rsnp:push"

    devices_show = File.read(
      File.expand_path("../app/views/recording_studio_notifications_push/devices/show.html.erb", __dir__)
    )
    assert_includes devices_show, "push_enable: true"
    assert_includes devices_show, "Push Notifications"
    assert_includes devices_show, "Get notifications on your devices"
    assert_includes devices_show, "Manage notifications"
    assert_includes devices_show, "@notifications_settings_path"
    assert_includes devices_show, "flex flex-wrap items-center gap-3"
    assert_includes devices_show, "enablePanel"
    refute_includes devices_show, "page_title.slot"
    assert_includes devices_show, "FlatPack::List::Component"
    assert_includes devices_show, "installation.list_icon"
    assert_includes devices_show, 'icon: "trash"'
    assert_includes devices_show, "icon_only: true"
    assert_includes devices_show, "turbo_method: :delete"
    refute_includes devices_show, "Active browsers and devices"
    refute_includes devices_show, "No devices yet"
    refute_includes devices_show, "push_disable"
    refute_includes devices_show, 'button_to "Remove"'
    assert_includes devices_show, "Not getting alerts?"
    assert_includes devices_show, "push-notification-help-modal"
    assert_includes devices_show, "Not receiving push notifications?"
    assert_includes devices_show, "helpSiteSteps"
    assert_includes devices_show, "Open this browser’s site settings for notifications"
    assert_includes devices_show, "Open your device notification settings"
    refute_includes devices_show, "helpDetected"
    refute_includes devices_show, "helpPermission"
    refute_includes devices_show, "We can spot your browser and OS"
    refute_includes devices_show, "refreshNotificationHelp"
    refute_includes devices_show, "Checking your browser"
  end

  def test_dummy_pwa_head_resolves_service_worker_via_main_app
    head = File.read(
      File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__)
    )

    assert_includes head, "main_app.pwa_service_worker_path"
    assert_includes head, "main_app.pwa_manifest_path"
    assert_includes head, "RecordingStudioPwa.serviceWorkerReady"
  end
end
