import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["locale", "timeZone"]
  static values = { defaultLocale: String }

  connect() {
    if (this.hasLocaleTarget) {
      this.enhanceLocaleLabels()

      if (!this.preferenceValue(this.localeTarget, "profile[locale]")) {
        requestAnimationFrame(() => this.selectLocale())
      }
    }

    if (this.hasTimeZoneTarget && !this.preferenceValue(this.timeZoneTarget, "profile[time_zone]")) {
      this.selectTimeZone()
    }
  }

  preferenceValue(target, inputName) {
    if ("value" in target) return target.value

    return target.querySelector(`input[name="${inputName}"]`)?.value
  }

  localeOptions() {
    return Array.from(this.localeTarget.querySelectorAll("[role='option'][data-value]")).filter(
      (option) => option.dataset.action?.includes("flat-pack--select#selectOption")
    )
  }

  preferredLocale(options) {
    const browserLocales = [...(navigator.languages || []), navigator.language].filter(Boolean)
    const supportedLocales = options.map((option) => ({
      locale: this.localeDetails(option.dataset.value),
      option
    })).filter(({ locale }) => locale)

    for (const browserLocale of browserLocales) {
      const locale = this.localeDetails(browserLocale)
      if (!locale) continue

      const exactMatch = supportedLocales.find(({ locale: supported }) => supported.canonical === locale.canonical)
      if (exactMatch) return exactMatch.option

      const likelyLocaleMatch = supportedLocales.find(
        ({ locale: supported }) => supported.language === locale.language &&
          supported.script === locale.script && supported.region === locale.region
      )
      if (likelyLocaleMatch) return likelyLocaleMatch.option

      const scriptMatch = supportedLocales.find(
        ({ locale: supported }) => supported.language === locale.language && supported.script === locale.script
      )
      if (scriptMatch) return scriptMatch.option

      const languageMatch = supportedLocales.find(({ locale: supported }) => supported.language === locale.language)
      if (languageMatch) return languageMatch.option
    }

    const defaultLocale = this.localeDetails(this.defaultLocaleValue)
    const defaultMatch = supportedLocales.find(
      ({ locale }) => locale.canonical === defaultLocale?.canonical
    )

    return defaultMatch?.option || supportedLocales[0]?.option
  }

  canonicalLocale(locale) {
    try {
      return new Intl.Locale(locale).baseName
    } catch {
      return null
    }
  }

  localeDetails(locale) {
    try {
      const parsedLocale = new Intl.Locale(locale)
      const likelyLocale = parsedLocale.maximize()

      return {
        canonical: parsedLocale.baseName,
        language: likelyLocale.language,
        script: likelyLocale.script,
        region: likelyLocale.region
      }
    } catch {
      return null
    }
  }

  selectLocale() {
    const option = this.preferredLocale(this.localeOptions())
    if (option) option.click()
  }

  enhanceLocaleLabels() {
    if (typeof Intl.DisplayNames !== "function") return

    try {
      const displayNames = new Intl.DisplayNames(
        [...(navigator.languages || []), navigator.language].filter(Boolean),
        { type: "language" }
      )

      this.localeOptions().forEach((option) => {
        if (option.dataset.label?.endsWith("(saved value)")) return

        const locale = this.canonicalLocale(option.dataset.value)
        const displayName = locale && displayNames.of(locale)
        if (!displayName) return

        const label = `${displayName} (${option.dataset.value})`
        option.dataset.label = label
        option.textContent = label
      })

      const selectedOption = this.localeTarget.querySelector("[role='option'][aria-selected='true']")
      const triggerLabel = this.localeTarget.querySelector("[data-flat-pack--select-target='trigger'] span")
      if (selectedOption && triggerLabel) triggerLabel.textContent = selectedOption.dataset.label
    } catch {
      // Keep server-rendered locale codes when display names are unavailable.
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