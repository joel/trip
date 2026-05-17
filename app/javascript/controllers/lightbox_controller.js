import { Controller } from "@hotwired/stimulus"

// Full-screen image viewer scoped to one image group (one journal entry,
// or the whole trip on the Gallery page). Pure Stimulus, no dependencies.
//
// The overlay is portalled to <body> on connect so its `position: fixed`
// is viewport-relative even when an ancestor of the controller element
// creates a containing block (the app shell uses transformed/filtered
// wrappers). Because the portalled overlay leaves the controller's DOM
// subtree, its controls are wired with explicit listeners rather than
// Stimulus `data-action` (which only binds within the controller).
//
// Markup contract (rendered by Components::Lightbox / LightboxOverlay):
//   root      data-controller="lightbox"
//             data-lightbox-urls-value='["/full/1.jpg", ...]'
//             data-lightbox-captions-value='["Entry · 14 May", ...]'
//   trigger   data-lightbox-target="trigger"
//             data-action="click->lightbox#open"
//             data-lightbox-index-param="<n>"
//   overlay   [data-lightbox-overlay] hidden  (+ [data-lightbox-image],
//             [data-lightbox-counter], [data-lightbox-caption],
//             [data-lightbox-nav], [data-lightbox-prev|next|close])
export default class extends Controller {
  static targets = ["trigger"]
  static values = {
    urls: Array, index: Number, captions: Array,
    kinds: Array, posters: Array
  }

  connect() {
    this.indexValue = 0
    this.overlay = this.element.querySelector("[data-lightbox-overlay]")
    if (!this.overlay) return

    // Return the overlay into the controller element before Turbo
    // snapshots the page, so the cached DOM is clean and a restoration
    // visit reconnects with the overlay where connect() expects it.
    this._beforeCache = () => {
      if (this.overlay && this.element.isConnected) {
        this.element.appendChild(this.overlay)
      }
    }
    document.addEventListener("turbo:before-cache", this._beforeCache)

    // Portal out of any transformed/filtered ancestor.
    document.body.appendChild(this.overlay)
    this.imageEl = this.overlay.querySelector("[data-lightbox-image]")
    this.videoEl = this.overlay.querySelector("[data-lightbox-video]")
    this.counterEl = this.overlay.querySelector("[data-lightbox-counter]")
    this.captionEl = this.overlay.querySelector("[data-lightbox-caption]")
    this.navEls = this.overlay.querySelectorAll("[data-lightbox-nav]")
    this.overlay.hidden = true

    this._onKey = this.onKey.bind(this)
    this._onClick = this.onOverlayClick.bind(this)
    this._onTouchStart = (e) => { this._touchX = e.changedTouches[0].clientX }
    this._onTouchEnd = this.onTouchEnd.bind(this)
    this.overlay.addEventListener("click", this._onClick)
    this.overlay.addEventListener("touchstart", this._onTouchStart)
    this.overlay.addEventListener("touchend", this._onTouchEnd)
  }

  disconnect() {
    this.unlock()
    document.removeEventListener("keydown", this._onKey)
    document.removeEventListener("turbo:before-cache", this._beforeCache)
    if (!this.overlay) return
    // Return it home if the element still lives (cache restore), else
    // drop the orphaned portal node.
    if (this.element.isConnected) {
      this.element.appendChild(this.overlay)
    } else {
      this.overlay.remove()
    }
  }

  // ── Open / close ──────────────────────────────────────────────

  open(event) {
    event.preventDefault()
    if (!this.overlay) return
    this.indexValue = Number(event.params.index ?? 0)
    this.render()
    this.overlay.hidden = false
    this.lock()
    document.addEventListener("keydown", this._onKey)
    this._lastFocus = document.activeElement
    this.closeButton?.focus()
  }

  close() {
    this.pauseVideo()
    this.overlay.hidden = true
    this.unlock()
    document.removeEventListener("keydown", this._onKey)
    this._lastFocus?.focus()
  }

  pauseVideo() {
    if (this.videoEl && !this.videoEl.paused) this.videoEl.pause()
  }

  onOverlayClick(event) {
    const action = event.target.closest(
      "[data-lightbox-prev],[data-lightbox-next],[data-lightbox-close]"
    )
    if (action?.hasAttribute("data-lightbox-prev")) return this.prev()
    if (action?.hasAttribute("data-lightbox-next")) return this.next()
    if (action?.hasAttribute("data-lightbox-close")) return this.close()
    // Bare scrim click (not a child) closes.
    if (event.target === this.overlay) this.close()
  }

  // ── Navigation ────────────────────────────────────────────────

  next() { this.go(1) }
  prev() { this.go(-1) }

  go(delta) {
    const n = this.urlsValue.length
    if (n === 0) return
    this.pauseVideo()
    this.indexValue = (this.indexValue + delta + n) % n // wrap both ends
    this.render()
  }

  render() {
    const i = this.indexValue
    const url = this.urlsValue[i]
    if (!url) return
    const isVideo = (this.kindsValue[i] || "image") === "video"
    if (isVideo && this.videoEl) {
      this.imageEl.hidden = true
      this.videoEl.hidden = false
      this.videoEl.poster = this.postersValue[i] || ""
      this.videoEl.src = url
      this.videoEl.load()
    } else {
      this.pauseVideo()
      if (this.videoEl) this.videoEl.hidden = true
      this.imageEl.hidden = false
      this.imageEl.src = url
    }
    if (this.counterEl) {
      this.counterEl.textContent = `${i + 1} / ${this.urlsValue.length}`
    }
    if (this.captionEl) {
      const caption = this.captionsValue[i]
      this.captionEl.textContent = caption ?? ""
      this.captionEl.hidden = !caption
    }
    const single = this.urlsValue.length <= 1
    this.navEls.forEach((el) => { el.hidden = single })
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

  onTouchEnd(event) {
    if (this._touchX == null) return
    const dx = event.changedTouches[0].clientX - this._touchX
    this._touchX = null
    if (Math.abs(dx) > 50) (dx < 0 ? this.next() : this.prev())
  }

  // ── Helpers ───────────────────────────────────────────────────

  get closeButton() {
    return this.overlay.querySelector("[data-lightbox-close]")
  }

  get focusables() {
    return Array.from(
      this.overlay.querySelectorAll(
        "button:not([disabled]), [href], [tabindex]:not([tabindex='-1'])"
      )
    ).filter((el) => !el.hidden && el.offsetParent !== null)
  }

  lock() {
    document.body.style.overflow = "hidden"
  }

  unlock() {
    document.body.style.overflow = ""
  }
}
