import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["banner"]

  connect() {
    this.deferredPrompt = null

    window.addEventListener("beforeinstallprompt", this.capturePrompt)
    window.addEventListener("appinstalled", this.handleInstalled)

    if (this.shouldShowBanner()) {
      this.incrementPageVisits()
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
    sessionStorage.setItem("pwa-banner-dismissed", "true")
  }

  // Private

  showBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.remove("hidden")
    }
  }

  hideBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.add("hidden")
    }
  }

  shouldShowBanner() {
    return !window.matchMedia("(display-mode: standalone)").matches
  }

  isDismissed() {
    return sessionStorage.getItem("pwa-banner-dismissed") === "true"
  }

  pageVisits() {
    return parseInt(sessionStorage.getItem("pwa-page-visits") || "0", 10)
  }

  incrementPageVisits() {
    const visits = this.pageVisits() + 1
    sessionStorage.setItem("pwa-page-visits", String(visits))
  }
}
