import { Controller } from "@hotwired/stimulus"

// Registers this browser for FCM push, or accepts a manual FID when Firebase
// ENV config is missing (dummy / local demos).
export default class extends Controller {
  static targets = ["manualFid", "enablePanel", "helpSiteSteps", "helpOsSteps"]
  static values = {
    registerUrl: String,
    unregisterUrlTemplate: String,
    vapidKey: String,
    firebaseConfig: Object,
    firebaseReady: Boolean,
    serviceWorkerPath: String,
    installations: Array
  }

  connect() {
    this.currentInstallation = null
    this.updateEnableLabel()
    this.showEnable()

    // Fill help content as soon as the controller connects so the modal is
    // ready before anyone taps "Not getting alerts?"
    requestAnimationFrame(() => this.fillNotificationHelp())

    this._onPushClick = (event) => {
      const enable = event.target.closest("[data-push-enable]")
      if (enable && this.element.contains(enable)) {
        this.enable(event)
      }
    }
    this.element.addEventListener("click", this._onPushClick)

    this._onTurboLoad = () => this.fillNotificationHelp()
    document.addEventListener("turbo:load", this._onTurboLoad)

    this.detectCurrentBrowser()
  }

  disconnect() {
    if (this._onPushClick) {
      this.element.removeEventListener("click", this._onPushClick)
      this._onPushClick = null
    }

    if (this._onTurboLoad) {
      document.removeEventListener("turbo:load", this._onTurboLoad)
      this._onTurboLoad = null
    }
  }

  async detectCurrentBrowser() {
    if (!this.firebaseReadyValue) return
    if (!("Notification" in window) || Notification.permission !== "granted") return

    try {
      const token = await this.fetchFirebaseToken()
      if (!token) return

      const match = (this.installationsValue || []).find(
        (row) => row.firebase_installation_id === token
      )
      if (!match) return

      this.currentInstallation = match
      this.hideEnablePanel()
      this.markCurrentInstallation(match.id)
    } catch (error) {
      console.warn("[push-devices] could not detect this browser", error)
    }
  }

  async enable(event) {
    event?.preventDefault?.()
    event?.stopPropagation?.()

    try {
      if (!("Notification" in window)) {
        throw new Error("This browser does not support notifications.")
      }

      const permission = await Notification.requestPermission()
      if (permission !== "granted") {
        return
      }

      const token = await this.fetchFirebaseToken()
      if (!token) {
        throw new Error("Could not get a Firebase token. Check the Firebase importmap pins.")
      }

      await this.registerInstallation(token)
      window.location.reload()
    } catch (error) {
      console.error("[push-devices] enable failed", error)
    }
  }

  async registerManualFid(event) {
    event?.preventDefault?.()
    const fid = this.hasManualFidTarget ? this.manualFidTarget.value.trim() : ""
    if (!fid) return

    try {
      await this.registerInstallation(fid)
      window.location.reload()
    } catch (error) {
      console.error("[push-devices] manual registration failed", error)
    }
  }

  async fetchFirebaseToken() {
    if (this.hasFirebaseReadyValue && !this.firebaseReadyValue) {
      return null
    }

    const config = this.firebaseConfigValue || {}
    const { initializeApp } = await import("firebase/app")
    const { getMessaging, getToken, isSupported } = await import("firebase/messaging")

    if (!(await isSupported())) {
      throw new Error("This browser does not support Firebase messaging.")
    }

    const app = initializeApp(config)
    const messaging = getMessaging(app)
    const registration = await this.resolveServiceWorkerRegistration()

    return getToken(messaging, {
      vapidKey: this.vapidKeyValue,
      serviceWorkerRegistration: registration
    })
  }

  async resolveServiceWorkerRegistration() {
    if (window.RecordingStudioPwa?.serviceWorkerReady) {
      try {
        return await window.RecordingStudioPwa.serviceWorkerReady
      } catch (error) {
        if (!String(error?.message || "").includes("not mounted")) {
          throw error
        }
      }
    }

    if (!("serviceWorker" in navigator)) {
      throw new Error("This browser does not support service workers.")
    }

    const existing = await navigator.serviceWorker.getRegistration()
    if (existing) return existing

    const path = this.hasServiceWorkerPathValue ? this.serviceWorkerPathValue : "/service-worker.js"
    await navigator.serviceWorker.register(path)
    return navigator.serviceWorker.ready
  }

  installedApp() {
    if (window.navigator.standalone === true) return true
    if (window.matchMedia("(display-mode: standalone)").matches) return true
    if (window.matchMedia("(display-mode: fullscreen)").matches) return true

    return false
  }

  updateEnableLabel() {
    if (!this.hasEnablePanelTarget) return

    const button = this.enablePanelTarget.querySelector("button")
    if (!button) return

    button.textContent = this.installedApp()
      ? "Enable on this device"
      : "Enable on this browser"
  }

  browserLabel() {
    const { browser, os } = this.detectClient()
    return `${browser} on ${os}`
  }

  detectClient() {
    const ua = navigator.userAgent || ""
    const platformHint = navigator.userAgentData?.platform || ""

    let browser = "Browser"
    if (/Edg\/|EdgiOS\//.test(ua)) browser = "Edge"
    else if (/OPR\/|OPiOS\//.test(ua)) browser = "Opera"
    else if (/CriOS\/|Chrome\//.test(ua)) browser = "Chrome"
    else if (/FxiOS\/|Firefox\//.test(ua)) browser = "Firefox"
    else if (/Safari\//.test(ua)) browser = "Safari"

    let os = "this device"
    if (/iPad|Macintosh/.test(ua) && navigator.maxTouchPoints > 1) os = "iPad"
    else if (/iPhone|iPod|iOS/.test(ua) || /iPhone|iPad|iOS/i.test(platformHint)) {
      os = /iPad/.test(ua) ? "iPad" : "iPhone"
    } else if (/Mac OS X|Macintosh|macOS/i.test(ua) || /macOS|Mac/i.test(platformHint)) os = "Mac"
    else if (/Windows|Win32|Win64/i.test(ua) || /Windows/i.test(platformHint)) os = "Windows"
    else if (/Android/i.test(ua) || /Android/i.test(platformHint)) os = "Android"
    else if (/Linux/i.test(ua) || /Linux/i.test(platformHint)) os = "Linux"

    return { browser, os }
  }

  fillNotificationHelp() {
    const client = this.detectClient()
    const guide = this.notificationHelpGuide(client)

    this.replaceStepList(this.helpTarget("helpSiteSteps"), guide.site)
    this.replaceStepList(this.helpTarget("helpOsSteps"), guide.os)
  }

  helpTarget(name) {
    if (this[`has${name.charAt(0).toUpperCase()}${name.slice(1)}Target`]) {
      return this[`${name}Target`]
    }

    return this.element.querySelector(
      `[data-recording-studio-notifications-push--push-devices-target="${name}"]`
    )
  }

  notificationHelpGuide({ browser, os }) {
    // Paths are kept in step with vendor guidance:
    // Chrome: support.google.com/chrome/answer/3220216
    // Edge: support.microsoft.com/edge/manage-website-notifications-in-microsoft-edge
    // Firefox: support.mozilla.org/kb/push-notifications-firefox
    // Safari: support.apple.com/guide/safari/customize-website-notifications-sfri40734/mac
    // iPhone/iPad: webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/
    if (["iPhone", "iPad"].includes(os)) {
      return this.appleMobileHelpGuide(browser)
    }

    const desktopSiteSteps = {
      Chrome: [
        "Click the lock or info icon in the address bar, or open chrome://settings/",
        "Open Privacy and security → Site settings → Notifications",
        "Choose Sites can ask to send notifications, then allow this site if it is blocked"
      ],
      Edge: [
        "Open Edge → Settings",
        "Open Privacy, search, and services → Site permissions → All sites",
        "Select this site, then set Notifications to Allow"
      ],
      Firefox: [
        "Open Firefox → Settings",
        "Under Privacy & Security → Permissions, open Notifications → Settings",
        "Find this site, choose Allow, then save changes"
      ],
      Safari: [
        "Open Safari → Settings",
        "Open Websites → Notifications",
        "Find this site and choose Allow"
      ],
      Opera: [
        "Open Opera → Settings",
        "Open Privacy & security → Site settings → Notifications",
        "Turn on Ask before sending and allow this site"
      ]
    }

    const site = os === "Android"
      ? this.androidSiteSteps(browser)
      : desktopSiteSteps[browser] || [
        "Open this browser’s site settings for notifications",
        "Find this site in the notification permissions",
        "Choose Allow, then tap Enable again"
      ]

    return { site, os: this.deviceNotificationSteps(browser, os) }
  }

  appleMobileHelpGuide(browser) {
    const unsupportedSetupBrowser = ["Firefox", "Opera"].includes(browser)
    const site = this.installedApp()
      ? [
          "Open this app from its Home Screen icon",
          "Tap Enable and choose Allow when prompted",
          "If notifications were blocked, use the device steps below"
        ]
      : unsupportedSetupBrowser
        ? [
            "Open this site in Safari, Chrome, or Edge",
            "Tap Share → Add to Home Screen, then open the new icon",
            "Open Push devices in the Home Screen app and tap Enable"
          ]
      : [
          "Use iOS or iPadOS 16.4 or later",
          "Tap Share → Add to Home Screen, then open the new icon",
          "Open Push devices in the Home Screen app and tap Enable"
        ]

    return {
      site,
      os: [
        "Open the Settings app",
        "Open Notifications and select this web app’s name",
        "Turn on Allow Notifications"
      ]
    }
  }

  androidSiteSteps(browser) {
    const appSteps = {
      Chrome: [
        "On this site, tap Page info beside the address bar",
        "Open Permissions → Notifications",
        "Choose Allow, then tap Enable again"
      ],
      Edge: [
        "Open Edge Settings → Site permissions",
        "Open Notifications and find this site",
        "Choose Allow, then tap Enable again"
      ],
      Firefox: [
        "Open this site’s permissions from the address bar",
        "Open Notifications for this site",
        "Choose Allow, then tap Enable again"
      ],
      Opera: [
        "Open the Opera menu → Notifications",
        "Find this website in the list",
        "Clear its saved choice, then return here and tap Enable"
      ]
    }

    return appSteps[browser] || [
      "Open this site’s permissions in the browser",
      "Open Notifications for this site",
      "Choose Allow, then tap Enable again"
    ]
  }

  deviceNotificationSteps(browser, os) {
    const appNames = {
      Chrome: "Google Chrome",
      Edge: "Microsoft Edge",
      Firefox: "Firefox",
      Opera: "Opera",
      Safari: "Safari"
    }
    const appName = appNames[browser] || browser

    if (os === "Mac") {
      return browser === "Safari"
        ? [
            "Open System Settings → Notifications",
            "Select this website under Application Notifications",
            "Turn on Allow notifications"
          ]
        : [
            "Open System Settings → Notifications",
            `Select ${appName}`,
            "Turn on Allow notifications"
          ]
    }

    if (os === "Windows") {
      return [
        "Open Settings → System → Notifications",
        `Under Notifications from apps and other senders, select ${appName}`,
        "Turn notifications on and enable notification banners"
      ]
    }

    if (os === "Android") {
      return [
        "Open Settings → Notifications → App notifications",
        `Select ${appName}`,
        "Turn notifications on"
      ]
    }

    if (os === "Linux") {
      return [
        "Open your desktop notification settings",
        `Find ${appName} in the application list`,
        "Allow notifications and turn off Do Not Disturb"
      ]
    }

    return [
      "Open your device notification settings",
      `Find ${appName} in the application list`,
      "Allow notifications, then try a test alert"
    ]
  }

  replaceStepList(listElement, steps) {
    if (!listElement) return

    listElement.replaceChildren()
    steps.forEach((step, index) => {
      const item = document.createElement("li")
      item.textContent = `${index + 1}. ${step}`
      listElement.appendChild(item)
    })
  }

  async registerInstallation(firebaseInstallationId, legacyFcmToken = null) {
    const body = {
      installation: {
        firebase_installation_id: firebaseInstallationId,
        legacy_fcm_token: legacyFcmToken,
        platform: this.installedApp() ? "pwa" : "web",
        label: this.browserLabel(),
        user_agent: navigator.userAgent
      }
    }

    const response = await fetch(this.registerUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify(body),
      credentials: "same-origin"
    })

    if (!response.ok) {
      let message = "Registration failed"
      try {
        const payload = await response.json()
        message = payload.error || message
      } catch (_error) {
        // ignore
      }
      throw new Error(message)
    }

    return response.json()
  }

  showEnable() {
    if (this.hasEnablePanelTarget) this.enablePanelTarget.classList.remove("hidden")
  }

  hideEnablePanel() {
    if (this.hasEnablePanelTarget) this.enablePanelTarget.classList.add("hidden")
  }

  markCurrentInstallation(id) {
    const row = this.element.querySelector(`[data-installation-id="${id}"]`)
    if (!row) return

    const label = row.querySelector("[data-installation-current-label]")
    if (label) label.classList.remove("hidden")
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
