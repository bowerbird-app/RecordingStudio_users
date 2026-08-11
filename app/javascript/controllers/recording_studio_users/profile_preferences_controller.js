import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["locale", "timeZone"]

  connect() {
    if (this.hasLocaleTarget && !this.localeTarget.value) {
      this.localeTarget.value = this.preferredLocale()
    }

    if (this.hasTimeZoneTarget && !this.preferenceValue(this.timeZoneTarget)) {
      this.selectTimeZone()
    }
  }

  preferenceValue(target) {
    if ("value" in target) return target.value

    return target.querySelector('input[name="profile[time_zone]"]')?.value
  }

  preferredLocale() {
    const browserLocales = [...(navigator.languages || []), navigator.language].filter(Boolean)
    const supportedLocales = ["en-US", "en-GB", "es-ES"]

    for (const browserLocale of browserLocales) {
      const locale = this.canonicalLocale(browserLocale)
      if (supportedLocales.includes(locale)) return locale
      if (locale === "es" || locale?.startsWith("es-")) return "es-ES"
      if (locale === "en" || locale?.startsWith("en-")) return "en-GB"
    }

    return "en-US"
  }

  canonicalLocale(locale) {
    try {
      return new Intl.Locale(locale).baseName
    } catch {
      return null
    }
  }

  selectTimeZone() {
    try {
      const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone
      if ("options" in this.timeZoneTarget) {
        const matchingOption = Array.from(this.timeZoneTarget.options).find((option) => option.value === timeZone)
        if (!matchingOption) return

        this.timeZoneTarget.value = timeZone
        return
      }

      const matchingOption = Array.from(this.timeZoneTarget.querySelectorAll("[data-value]")).find(
        (option) => option.dataset.value === timeZone && option.dataset.action?.includes("flat-pack--select#selectOption")
      )
      if (matchingOption) requestAnimationFrame(() => matchingOption.click())
    } catch {
      // Leave the preference unset when browser detection is unavailable.
    }
  }
}