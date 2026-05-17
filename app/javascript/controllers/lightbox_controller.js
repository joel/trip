import { Controller } from "@hotwired/stimulus"

// Full-screen image viewer scoped to one image group (one journal entry,
// or the whole trip on the Gallery page). Pure Stimulus, no dependencies.
//
// Markup contract (rendered by Components::Lightbox):
//   root      data-controller="lightbox"
//             data-lightbox-urls-value='["/full/1.jpg", ...]'
//             data-lightbox-captions-value='["Entry · 14 May", ...]'  (optional)
//   trigger   data-lightbox-target="trigger"
//             data-action="click->lightbox#open"
//             data-lightbox-index-param="<n>"
//   overlay   data-lightbox-target="overlay" hidden
//   image     data-lightbox-target="image"
//   counter   data-lightbox-target="counter"   (optional)
//   caption   data-lightbox-target="caption"   (optional)
//   close btn data-lightbox-close              + data-action="lightbox#close"
//   prev/next data-action="lightbox#prev" / "lightbox#next"
export default class extends Controller {
  static targets = ["overlay", "image", "counter", "caption", "trigger", "nav"]
  static values = { urls: Array, index: Number, captions: Array }

  connect() {
    this.indexValue = 0
    this.overlayTarget.hidden = true
    this._onKey = this.onKey.bind(this)
    this._touchX = null
  }

  disconnect() {
    // Safety net for Turbo navigation away while the overlay is open.
    this.unlock()
    document.removeEventListener("keydown", this._onKey)
  }

  // ── Open / close ──────────────────────────────────────────────

  open(event) {
    event.preventDefault()
    this.indexValue = Number(event.params.index ?? 0)
    this.render()
    this.overlayTarget.hidden = false
    this.lock()
    document.addEventListener("keydown", this._onKey)
    this._lastFocus = document.activeElement
    this.closeButton?.focus()
  }

  close() {
    this.overlayTarget.hidden = true
    this.unlock()
    document.removeEventListener("keydown", this._onKey)
    this._lastFocus?.focus()
  }

  // Close only when the scrim itself (not its children) is clicked.
  backdrop(event) {
    if (event.target === this.overlayTarget) this.close()
  }

  // ── Navigation ────────────────────────────────────────────────

  next() { this.go(1) }
  prev() { this.go(-1) }

  go(delta) {
    const n = this.urlsValue.length
    if (n === 0) return
    this.indexValue = (this.indexValue + delta + n) % n // wrap both ends
    this.render()
  }

  render() {
    const i = this.indexValue
    const url = this.urlsValue[i]
    if (!url) return
    this.imageTarget.src = url
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${i + 1} / ${this.urlsValue.length}`
    }
    if (this.hasCaptionTarget) {
      const caption = this.captionsValue[i]
      this.captionTarget.textContent = caption ?? ""
      this.captionTarget.hidden = !caption
    }
    // Prev/Next make no sense for a single image.
    const single = this.urlsValue.length <= 1
    this.navTargets.forEach((el) => { el.hidden = single })
  }

  // ── Keyboard ──────────────────────────────────────────────────

  onKey(event) {
    switch (event.key) {
      case "Escape":
        this.close()
        break
      case "ArrowRight":
        this.next()
        break
      case "ArrowLeft":
        this.prev()
        break
      case "Tab":
        this.trapFocus(event)
        break
    }
  }

  trapFocus(event) {
    const focusables = this.focusables
    if (focusables.length === 0) return
    const first = focusables[0]
    const last = focusables[focusables.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  // ── Touch swipe ───────────────────────────────────────────────

  touchStart(event) {
    this._touchX = event.changedTouches[0].clientX
  }

  touchEnd(event) {
    if (this._touchX === null) return
    const dx = event.changedTouches[0].clientX - this._touchX
    this._touchX = null
    if (Math.abs(dx) > 50) (dx < 0 ? this.next() : this.prev())
  }

  // ── Helpers ───────────────────────────────────────────────────

  get closeButton() {
    return this.overlayTarget.querySelector("[data-lightbox-close]")
  }

  get focusables() {
    return Array.from(
      this.overlayTarget.querySelectorAll(
        "button:not([disabled]), [href], [tabindex]:not([tabindex='-1'])"
      )
    ).filter((el) => !el.hidden && el.offsetParent !== null)
  }

  lock() {
    this._scrollY = window.scrollY
    document.body.style.overflow = "hidden"
  }

  unlock() {
    document.body.style.overflow = ""
  }
}
