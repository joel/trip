import { Controller } from "@hotwired/stimulus"

// Effortless, polite inline video. Plays muted only when in view and
// only where the browser/user permits it; pauses when scrolled away.
// Honours prefers-reduced-motion and Save-Data / slow connections —
// in those cases it never autoplays (poster + native controls only).
export default class extends Controller {
  connect() {
    this.el = this.element // the <video>
    if (this.shouldNotAutoplay()) {
      // Respect the user: poster + controls, load nothing eagerly.
      this.el.preload = "none"
      return
    }
    this._io = new IntersectionObserver(
      (entries) => this.onIntersect(entries),
      { threshold: 0.5 }
    )
    this._io.observe(this.el)
  }

  disconnect() {
    this._io?.disconnect()
    if (this.el && !this.el.paused) this.el.pause()
  }

  onIntersect(entries) {
    const entry = entries[0]
    if (!entry) return
    if (entry.isIntersecting) {
      this.tryPlay()
    } else if (!this.el.paused) {
      this.el.pause()
    }
  }

  tryPlay() {
    // Muted + playsinline is required for the autoplay policy; honour
    // a rejected promise (browser blocked it) by leaving the poster.
    this.el.muted = true
    const p = this.el.play()
    if (p && typeof p.catch === "function") p.catch(() => {})
  }

  shouldNotAutoplay() {
    const reduced = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches
    const c = navigator.connection || {}
    const saveData = c.saveData === true
    const slow = /(^|-)2g$/.test(c.effectiveType || "")
    return reduced || saveData || slow
  }
}
