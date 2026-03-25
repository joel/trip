import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["banner", "installButton", "iosInstructions"]

  connect() {
    this.deferredPrompt = null

    window.addEventListener("beforeinstallprompt", this.capturePrompt)
    window.addEventListener("appinstalled", this.handleInstalled)

    if (this.shouldShowBanner()) {
      this.incrementPageVisits()

      if (this.isIos() && this.pageVisits() >= 2 && !this.isDismissed()) {
        this.showBanner()
        this.showIosInstructions()
      }
    }
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.capturePrompt)
    window.removeEventListener("appinstalled", this.handleInstalled)
  }

  capturePrompt = (event) => {
    event.preventDefault()
    this.deferredPrompt = event

    if (this.pageVisits() >= 2 && !this.isDismissed()) {
      this.showBanner()
    }
  }

  handleInstalled = () => {
    this.hideBanner()
    this.deferredPrompt = null
  }

  async install() {
    if (!this.deferredPrompt) return

    this.deferredPrompt.prompt()
    await this.deferredPrompt.userChoice
    this.deferredPrompt = null
    this.hideBanner()
  }

  dismiss() {
    this.hideBanner()
    localStorage.setItem("pwa-banner-dismissed", "true")
  }

  // Private

  showBanner() {
    if (!this.hasBannerTarget) return

    this.bannerTarget.classList.remove("opacity-0", "translate-y-4",
      "pointer-events-none")
    this.bannerTarget.classList.add("opacity-100", "translate-y-0",
      "pointer-events-auto")
  }

  hideBanner() {
    if (!this.hasBannerTarget) return

    this.bannerTarget.classList.add("opacity-0", "translate-y-4",
      "pointer-events-none")
    this.bannerTarget.classList.remove("opacity-100", "translate-y-0",
      "pointer-events-auto")
  }

  showIosInstructions() {
    if (this.hasInstallButtonTarget) {
      this.installButtonTarget.classList.add("hidden")
    }
    if (this.hasIosInstructionsTarget) {
      this.iosInstructionsTarget.classList.remove("hidden")
    }
  }

  shouldShowBanner() {
    return !window.matchMedia("(display-mode: standalone)").matches
  }

  isDismissed() {
    return localStorage.getItem("pwa-banner-dismissed") === "true"
  }

  isIos() {
    return /iPad|iPhone|iPod/.test(navigator.userAgent) ||
      (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
  }

  pageVisits() {
    return parseInt(sessionStorage.getItem("pwa-page-visits") || "0", 10)
  }

  incrementPageVisits() {
    const visits = this.pageVisits() + 1
    sessionStorage.setItem("pwa-page-visits", String(visits))
  }
}
